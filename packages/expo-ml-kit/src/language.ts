import { nativeFunction } from './ExpoMlKitModule';

/** A language ML Kit identified (BCP-47; `und`: could not tell) and how sure
 *  it is (0-1). */
export type MlKitIdentifiedLanguage = { language: string; confidence: number };

export type MlKitLanguageIdOptions = {
  /** Answers below this confidence count as `und` (ML Kit's default: 0.5
   *  for one language, 0.01 for the possible ones). */
  confidenceThreshold?: number;
};

/** One message of a conversation, oldest first. `timestamp` is ms since the
 *  epoch; `userId` names a remote user, and is left out for the local one. */
export type MlKitConversationMessage = {
  text: string;
  timestamp: number;
  userId?: string;
};

/** Smart Reply's answer: up to three replies, or why there are none
 *  (`notSupportedLanguage`: the conversation is not in English). */
export type MlKitSmartReplies = {
  status: 'success' | 'notSupportedLanguage' | 'noReply';
  suggestions: string[];
};

declare module './ExpoMlKitModule' {
  interface ExpoMlKitFunctions {
    identifyLanguage(
      text: string,
      options: MlKitLanguageIdOptions
    ): Promise<string>;
    identifyPossibleLanguages(
      text: string,
      options: MlKitLanguageIdOptions
    ): Promise<MlKitIdentifiedLanguage[]>;
    suggestReplies(
      messages: readonly MlKitConversationMessage[]
    ): Promise<MlKitSmartReplies>;
  }
}

/** Language Identification (bundled, 100+ languages): `text`'s language as
 *  a BCP-47 tag, or `und`. */
export async function identifyLanguage(
  text: string,
  options: MlKitLanguageIdOptions = {}
): Promise<string> {
  return nativeFunction('identifyLanguage', 'languageId')(text, options);
}

/** Every language `text` may be in, most likely first. */
export async function identifyPossibleLanguages(
  text: string,
  options: MlKitLanguageIdOptions = {}
): Promise<MlKitIdentifiedLanguage[]> {
  return nativeFunction('identifyPossibleLanguages', 'languageId')(
    text,
    options
  );
}

/** Smart Reply (bundled, English): replies the local user might send to the
 *  conversation's last message, which must be a remote user's. */
export async function suggestReplies(
  messages: readonly MlKitConversationMessage[]
): Promise<MlKitSmartReplies> {
  return nativeFunction('suggestReplies', 'smartReply')(messages);
}
