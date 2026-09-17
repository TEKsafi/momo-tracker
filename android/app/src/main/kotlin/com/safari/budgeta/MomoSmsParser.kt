package com.safari.budgeta

import java.util.Locale

data class MomoSmsPayload(
    val sender: String,
    val rawBody: String,
    val amount: String?,
    val referenceId: String?,
    val isFlash: Boolean,
)

object MomoSmsParser {
    fun parse(sender: String, body: String, isFlash: Boolean): MomoSmsPayload {
        val normalizedBody = body.replace("\r", " ").replace("\n", " ")
        val amount = extractAmount(normalizedBody)
        val referenceId = extractReferenceId(normalizedBody)
        return MomoSmsPayload(
            sender = sender,
            rawBody = normalizedBody,
            amount = amount,
            referenceId = referenceId,
            isFlash = isFlash,
        )
    }

    private fun extractAmount(text: String): String? {
        val patterns = listOf(
            Regex("""(?i)(?:received|credited|payment of|transferred|withdrawn|debit(?:ed)?|purchased|paid)[^0-9]{0,20}([0-9][0-9,]*(?:\.\d+)?)\s*RWF"""),
            Regex("""(?i)([0-9][0-9,]*(?:\.\d+)?)\s*RWF""")
        )

        for (regex in patterns) {
            val match = regex.find(text)
            if (match != null) {
                return match.groupValues[1].replace(",", "")
            }
        }

        return null
    }

    private fun extractReferenceId(text: String): String? {
        val patterns = listOf(
            Regex("""(?i)(?:financial transaction id|transaction(?:\s+id)?|txid|ft\s*id|et\s*id|reference|ref)\s*[:=]?\s*([A-Za-z0-9]+)"""),
            Regex("""(?i)(?:ref(?:erence)?)\s*[:=]?\s*([A-Za-z0-9]+)""")
        )

        for (regex in patterns) {
            val match = regex.find(text)
            if (match != null) return match.groupValues[1]
        }

        return null
    }

    fun isMomoSender(sender: String?): Boolean {
        if (sender.isNullOrBlank()) return false
        val normalized = sender.lowercase(Locale.ROOT).replace(Regex("[^a-z0-9]"), "")
        return normalized.contains("mmoney") ||
            normalized.contains("money") ||
            normalized.contains("mtn")
    }

    fun isMomoBody(body: String): Boolean {
        val text = body.lowercase(Locale.ROOT)
        val keywords = listOf(
            "m-money",
            "mobile money",
            "received",
            "payment of",
            "transferred",
            "withdrawn",
            "credited",
            "debited",
            "balance",
            "transaction",
            "airtime",
            "wallet"
        )
        return keywords.any { text.contains(it) }
    }
}
