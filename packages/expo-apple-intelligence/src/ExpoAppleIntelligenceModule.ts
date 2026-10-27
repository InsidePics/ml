import { NativeModule, requireNativeModule } from 'expo';
import type { SharedRef } from 'expo-modules-core/types';

import type {
  ExpoAppleIntelligenceModuleEvents,
  ImageAnalysisResult,
  FaceObservation,
  TextObservation,
  ClassificationObservation,
  BarcodeObservation,
  BodyPoseObservation,
  HandPoseObservation,
  AnimalObservation,
  RectangleObservation,
  FeaturePrintResult,
  AestheticsResult,
  SaliencyResult,
  HorizonResult,
  LensSmudgeResult,
  DocumentRecognitionResult,
  TranscriptionResult,
} from './ExpoAppleIntelligence.types';

/** Any Expo image handle: from expo-image-manipulator, expo-image, or
 *  expo-image-ml-tools' `warp`. Every image function takes one. */
export type ImageRef = SharedRef<'image'>;

declare class ExpoAppleIntelligenceModule extends NativeModule<ExpoAppleIntelligenceModuleEvents> {
  /** Run all available analyses in a single pass (most efficient) */
  analyzeImage(image: ImageRef): Promise<ImageAnalysisResult>;

  /** Face detection with landmarks, quality, angles */
  detectFaces(image: ImageRef): Promise<FaceObservation[]>;

  /** OCR text recognition — array of observations with candidates */
  recognizeText(image: ImageRef): Promise<TextObservation[]>;

  /** Image classification — all observations, unfiltered */
  classifyImage(image: ImageRef): Promise<ClassificationObservation[]>;

  /** Barcode and QR code detection */
  detectBarcodes(image: ImageRef): Promise<BarcodeObservation[]>;

  /** Human body pose detection */
  detectBodyPoses(image: ImageRef): Promise<BodyPoseObservation[]>;

  /** Hand pose detection */
  detectHandPoses(image: ImageRef): Promise<HandPoseObservation[]>;

  /** Image similarity vector */
  generateFeaturePrint(image: ImageRef): Promise<FeaturePrintResult | null>;

  /** Aesthetic quality score (iOS 18+/macOS 15+ only, returns null otherwise) */
  calculateAesthetics(image: ImageRef): Promise<AestheticsResult | null>;

  /** Salient regions */
  detectSaliency(image: ImageRef): Promise<SaliencyResult | null>;

  /** Animal detection with all labels */
  detectAnimals(image: ImageRef): Promise<AnimalObservation[]>;

  /** Rectangle detection with corner points */
  detectRectangles(image: ImageRef): Promise<RectangleObservation[]>;

  /** Horizon angle in radians */
  detectHorizon(image: ImageRef): Promise<HorizonResult | null>;

  /** Lens smudge detection (iOS 26+/macOS 26+ only, returns null otherwise) */
  detectLensSmudge(image: ImageRef): Promise<LensSmudgeResult | null>;

  /** Structured document recognition (iOS 26+/macOS 26+ only, returns null otherwise) */
  recognizeDocument(image: ImageRef): Promise<DocumentRecognitionResult | null>;

  /** Check if on-device Foundation Model is available (iOS 26+) */
  isFoundationModelAvailable(): boolean;

  /** Generate text using on-device Foundation Model (iOS 26+ only) */
  generateText(prompt: string, systemPrompt?: string): Promise<string | null>;

  /** Transcribe audio file to text (iOS 26+ only) */
  transcribeAudio(
    audioPath: string,
    locale?: string
  ): Promise<TranscriptionResult | null>;

  /** Generate image from text prompt using ImagePlayground (iOS 18.4+ only) */
  generateImage(
    prompt: string,
    style?: 'animation' | 'illustration' | 'sketch'
  ): Promise<string | null>;
}

export default requireNativeModule<ExpoAppleIntelligenceModule>(
  'ExpoAppleIntelligence'
);
