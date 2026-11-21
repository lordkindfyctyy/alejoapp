package com.alejoapp.alejoapp

import android.content.Intent
import android.nfc.NdefMessage
import android.nfc.NdefRecord
import android.nfc.NfcAdapter
import android.nfc.Tag
import android.nfc.tech.Ndef
import android.nfc.tech.NdefFormatable
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Stickers NFC de la casa (heladera, baño, cama...). Un sticker grabado con
 * alejoapp://picto/<id>?l=<NOMBRE> abre la app y muestra ese pictograma: con la app cerrada lo
 * abre Android por el intent-filter NDEF_DISCOVERED del manifest, y con la app abierta llega
 * por onNewIntent.
 *
 * Canal "alejoapp/nfc" (lib/stickers_nfc.dart):
 *   estado -> "sin" (no tiene NFC), "apagado" o "listo"
 *   linkInicial -> el link del sticker que abrió la app (una sola vez) o null
 *   grabar(uri) -> espera un sticker hasta 60 s y lo graba; devuelve "ok" o el problema
 *   cancelar
 * y la app recibe "abrir"(uri) cuando tocan un sticker con la app abierta.
 */
class MainActivity : FlutterActivity() {
    private var canal: MethodChannel? = null
    private var linkInicial: String? = null
    private var grabando: MethodChannel.Result? = null
    private var vuelta = 0 // para que el tiempo límite de una grabación vieja no corte una nueva
    private val principal = Handler(Looper.getMainLooper())

    override fun onCreate(savedInstanceState: Bundle?) {
        linkInicial = linkDe(intent)
        super.onCreate(savedInstanceState)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        canal = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "alejoapp/nfc").also {
            it.setMethodCallHandler { call, result ->
                when (call.method) {
                    "estado" -> result.success(estado())
                    "linkInicial" -> {
                        result.success(linkInicial)
                        linkInicial = null
                    }
                    "grabar" -> grabar(call.argument<String>("uri") ?: "", result)
                    "cancelar" -> {
                        terminar("cancelado")
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        linkDe(intent)?.let { canal?.invokeMethod("abrir", it) }
    }

    override fun onPause() {
        // El modo para grabar solo funciona con la app adelante
        terminar("cancelado")
        super.onPause()
    }

    private fun linkDe(intent: Intent?): String? {
        val data = intent?.data ?: return null
        return if (data.scheme == "alejoapp") data.toString() else null
    }

    private fun estado(): String {
        val nfc = NfcAdapter.getDefaultAdapter(this) ?: return "sin"
        return if (nfc.isEnabled) "listo" else "apagado"
    }

    private fun grabar(uri: String, result: MethodChannel.Result) {
        val nfc = NfcAdapter.getDefaultAdapter(this)
        if (nfc == null) {
            result.success("Este teléfono no tiene NFC")
            return
        }
        if (!nfc.isEnabled) {
            result.success("El NFC está apagado: prendelo en los ajustes del teléfono")
            return
        }
        terminar("cancelado")
        grabando = result
        val estaVuelta = ++vuelta
        // El link primero (lo que abre el pictograma) y después el nombre de la app, para que
        // Android la abra a ella.
        val mensaje = NdefMessage(
            arrayOf(NdefRecord.createUri(uri), NdefRecord.createApplicationRecord(packageName))
        )
        // Sin FLAG_READER_SKIP_NDEF_CHECK: con ese flag Android no revisa si el sticker es NDEF, Ndef.get()
        // devuelve null y parecía que ningún sticker servía.
        val tipos = NfcAdapter.FLAG_READER_NFC_A or NfcAdapter.FLAG_READER_NFC_B or
            NfcAdapter.FLAG_READER_NFC_F or NfcAdapter.FLAG_READER_NFC_V
        nfc.enableReaderMode(this, { tag -> escribir(tag, mensaje) }, tipos, null)
        principal.postDelayed({
            if (estaVuelta == vuelta) terminar("No se acercó ningún sticker. Probá de nuevo.")
        }, 60000)
    }

    // Corre en otro hilo (el del lector NFC)
    private fun escribir(tag: Tag, mensaje: NdefMessage) {
        val respuesta = try {
            val ndef = Ndef.get(tag)
            if (ndef != null) {
                ndef.connect()
                try {
                    when {
                        !ndef.isWritable -> "Ese sticker está bloqueado y no se puede grabar"
                        ndef.maxSize < mensaje.toByteArray().size -> "El sticker es muy chico para este pictograma"
                        else -> {
                            ndef.writeNdefMessage(mensaje)
                            "ok"
                        }
                    }
                } finally {
                    ndef.close()
                }
            } else {
                val nuevo = NdefFormatable.get(tag)
                if (nuevo != null) {
                    nuevo.connect()
                    try {
                        nuevo.format(mensaje)
                        "ok"
                    } finally {
                        nuevo.close()
                    }
                } else {
                    "Ese sticker no sirve para grabar (no es NFC NDEF)"
                }
            }
        } catch (e: Exception) {
            "No se pudo grabar. Dejá el sticker quieto contra el celular y probá de nuevo."
        }
        principal.post { terminar(respuesta) }
    }

    private fun terminar(respuesta: String) {
        val resultado = grabando ?: return
        grabando = null
        vuelta++
        try {
            NfcAdapter.getDefaultAdapter(this)?.disableReaderMode(this)
        } catch (e: Exception) {
            // ya estaba apagado
        }
        resultado.success(respuesta)
    }
}
