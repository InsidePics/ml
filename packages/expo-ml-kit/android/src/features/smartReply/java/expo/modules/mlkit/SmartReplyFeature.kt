package expo.modules.mlkit

import com.google.mlkit.nl.smartreply.SmartReply
import com.google.mlkit.nl.smartreply.SmartReplySuggestionResult
import com.google.mlkit.nl.smartreply.TextMessage
import expo.modules.kotlin.Promise
import expo.modules.kotlin.modules.ModuleDefinitionBuilder

/** Smart Reply (bundled, English): up to three replies to a conversation's
 *  last message, from the local user's side. */
object SmartReplyFeature : MlKitFeature {
  override val name = "smartReply"

  private val generator by lazy { SmartReply.getClient() }

  private val STATUSES = mapOf(
    SmartReplySuggestionResult.STATUS_SUCCESS to "success",
    SmartReplySuggestionResult.STATUS_NOT_SUPPORTED_LANGUAGE to "notSupportedLanguage",
    SmartReplySuggestionResult.STATUS_NO_REPLY to "noReply",
  )

  /** `MlKitConversationMessage`: the local user's own, or a remote user's. */
  private fun message(raw: Map<String, Any?>): TextMessage {
    val text = raw["text"] as? String ?: throw IllegalArgumentException("A message has no text")
    val timestamp = (raw["timestamp"] as? Number)?.toLong() ?: throw IllegalArgumentException("A message has no timestamp")
    val user = raw["userId"] as? String
    return if (user == null) TextMessage.createForLocalUser(text, timestamp)
    else TextMessage.createForRemoteUser(text, timestamp, user)
  }

  /** `MlKitSmartReplies` for the conversation, oldest message first. */
  fun suggest(messages: List<Map<String, Any?>>): Map<String, Any> {
    val result = awaitDetector(generator.suggestReplies(messages.map(::message)))
    return mapOf("status" to (STATUSES[result.status] ?: "noReply"), "suggestions" to result.suggestions.map { it.text })
  }

  override fun define(module: ModuleDefinitionBuilder) {
    module.AsyncFunction("suggestReplies") { messages: List<Map<String, Any?>>, promise: Promise ->
      MlKitCalls.onQueue(promise) { suggest(messages) }
    }
  }
}
