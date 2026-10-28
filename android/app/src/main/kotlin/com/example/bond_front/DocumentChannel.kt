package com.example.bond_front

import android.app.Activity
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.Color
import android.graphics.pdf.PdfRenderer
import android.os.ParcelFileDescriptor
import android.provider.OpenableColumns
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.io.File
import java.util.concurrent.Executors

/** Android-only SAF picker and private PDF rendering. No broad storage permission. */
class DocumentChannel(private val activity: Activity, messenger: BinaryMessenger) {
    private val channel = MethodChannel(messenger, "bond/documents")
    private val executor = Executors.newSingleThreadExecutor()
    private var pending: MethodChannel.Result? = null
    private val maxBytes = 10_485_760

    init {
        // Recover temporary render files after a process crash.
        activity.cacheDir.listFiles()?.filter { it.name.startsWith("bond-document-") }?.forEach { it.delete() }
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "pick" -> {
                    if (pending != null) result.error("BUSY", "Ya hay un selector abierto.", null)
                    else {
                        pending = result
                        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
                            addCategory(Intent.CATEGORY_OPENABLE)
                            type = "*/*"
                            putExtra(Intent.EXTRA_MIME_TYPES, arrayOf("application/pdf", "image/jpeg", "image/png", "image/webp"))
                        }
                        try { activity.startActivityForResult(intent, 4712) }
                        catch (e: Exception) { pending = null; result.error("PICK", "No se pudo abrir el selector de archivos.", null) }
                    }
                }
                "renderPdf" -> {
                    val bytes = call.argument<ByteArray>("bytes")
                    val page = call.argument<Int>("page") ?: 0
                    if (bytes == null || bytes.size > maxBytes || page < 0) result.error("PDF", "PDF inválido.", null)
                    else executor.execute {
                        var temp: File? = null
                        try {
                            temp = File.createTempFile("bond-document-", ".pdf", activity.cacheDir)
                            temp.writeBytes(bytes)
                            val output = ParcelFileDescriptor.open(temp, ParcelFileDescriptor.MODE_READ_ONLY).use { descriptor ->
                                // Unlink immediately; only the private open descriptor can access it.
                                temp.delete()
                                PdfRenderer(descriptor).use { renderer ->
                                    require(page < renderer.pageCount)
                                    renderer.openPage(page).use { pdfPage ->
                                        val scale = 1600.0 / maxOf(pdfPage.width, pdfPage.height)
                                        val bitmap = Bitmap.createBitmap(maxOf(1, (pdfPage.width * scale).toInt()), maxOf(1, (pdfPage.height * scale).toInt()), Bitmap.Config.ARGB_8888)
                                        try {
                                            bitmap.eraseColor(Color.WHITE)
                                            pdfPage.render(bitmap, null, null, PdfRenderer.Page.RENDER_MODE_FOR_DISPLAY)
                                            val stream = ByteArrayOutputStream()
                                            bitmap.compress(Bitmap.CompressFormat.PNG, 100, stream)
                                            mapOf("image" to stream.toByteArray(), "pages" to renderer.pageCount)
                                        } finally { bitmap.recycle() }
                                    }
                                }
                            }
                            activity.runOnUiThread { result.success(output) }
                        } catch (e: Exception) {
                            activity.runOnUiThread { result.error("PDF", "No se pudo abrir el PDF. Puede estar dañado o protegido con contraseña.", null) }
                        } finally { temp?.delete() }
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode != 4712) return false
        val result = pending ?: return true
        pending = null
        val uri = data?.data
        if (resultCode != Activity.RESULT_OK || uri == null) { result.success(null); return true }
        executor.execute {
            try {
                var name = "documento"
                activity.contentResolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME, OpenableColumns.SIZE), null, null, null)?.use { cursor ->
                    if (cursor.moveToFirst()) {
                        val sizeIndex = cursor.getColumnIndex(OpenableColumns.SIZE)
                        if (sizeIndex >= 0 && !cursor.isNull(sizeIndex)) require(cursor.getLong(sizeIndex) <= maxBytes)
                        val nameIndex = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                        if (nameIndex >= 0) name = cursor.getString(nameIndex) ?: name
                    }
                }
                val mime = activity.contentResolver.getType(uri) ?: "application/octet-stream"
                require(mime in listOf("application/pdf", "image/jpeg", "image/png", "image/webp"))
                val bytes = activity.contentResolver.openInputStream(uri)!!.use { input ->
                    val output = ByteArrayOutputStream()
                    val buffer = ByteArray(8192)
                    while (true) {
                        val count = input.read(buffer)
                        if (count < 0) break
                        require(output.size() + count <= maxBytes)
                        output.write(buffer, 0, count)
                    }
                    output.toByteArray()
                }
                require(bytes.isNotEmpty())
                activity.runOnUiThread { result.success(mapOf("name" to name, "mimeType" to mime, "bytes" to bytes)) }
            } catch (e: Exception) {
                activity.runOnUiThread { result.error("FILE", "No se pudo leer el archivo. Usá PDF, JPG, PNG o WebP de hasta 10 MB.", null) }
            }
        }
        return true
    }
    fun close() {
        channel.setMethodCallHandler(null)
        pending?.error("CLOSED", "El selector se cerró.", null)
        pending = null
        executor.shutdown()
    }
}
