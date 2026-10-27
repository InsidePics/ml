package expo.modules.mlkit

/** Just enough JSON for the test fixture: maps, lists, numbers, strings. */
object Json {
  fun encode(value: Any?): String = when (value) {
    null -> "null"
    is String -> "\"" + value.replace("\\", "\\\\").replace("\"", "\\\"") + "\""
    is Map<*, *> -> value.entries.sortedBy { it.key.toString() }
      .joinToString(",", "{", "}") { encode(it.key.toString()) + ":" + encode(it.value) }
    is List<*> -> value.joinToString(",", "[", "]") { encode(it) }
    is Double -> if (value == Math.floor(value) && !value.isInfinite()) value.toLong().toString() else value.toString()
    else -> value.toString()
  }
}
