import type { MlKitPoint, MlKitRect } from './ExpoMlKit.types';
import { nativeFunction, type ImageRef } from './ExpoMlKitModule';

/** What ML Kit parsed a code's value as. */
export type MlKitBarcodeValueType =
  | 'unknown'
  | 'contactInfo'
  | 'email'
  | 'isbn'
  | 'phone'
  | 'product'
  | 'sms'
  | 'text'
  | 'url'
  | 'wifi'
  | 'geo'
  | 'calendarEvent'
  | 'driverLicense';

type Kind = 'work' | 'home' | 'unknown';
export type MlKitBarcodeEmail = {
  address: string | null;
  subject: string | null;
  body: string | null;
  type: Kind;
};
export type MlKitBarcodePhone = {
  number: string | null;
  type: Kind | 'fax' | 'mobile';
};
export type MlKitBarcodeContact = {
  name: {
    formattedName: string | null;
    pronunciation: string | null;
    prefix: string | null;
    first: string | null;
    middle: string | null;
    last: string | null;
    suffix: string | null;
  } | null;
  organization: string | null;
  title: string | null;
  phones: MlKitBarcodePhone[];
  emails: MlKitBarcodeEmail[];
  urls: string[];
  addresses: { lines: string[]; type: Kind }[];
};
/** `start`/`end` are ISO 8601: with `Z` when the code gives UTC (always, on
 *  iOS, where ML Kit hands over an instant), else the code's local time. */
export type MlKitBarcodeEvent = {
  summary: string | null;
  description: string | null;
  location: string | null;
  organizer: string | null;
  status: string | null;
  start: string | null;
  end: string | null;
};
/** An AAMVA driver licence or ID card (PDF417), its fields as printed. */
export type MlKitBarcodeLicense = Record<
  | 'documentType'
  | 'firstName'
  | 'middleName'
  | 'lastName'
  | 'gender'
  | 'addressStreet'
  | 'addressCity'
  | 'addressState'
  | 'addressZip'
  | 'licenseNumber'
  | 'issueDate'
  | 'expiryDate'
  | 'birthDate'
  | 'issuingCountry',
  string | null
>;

/** A code's content: what it holds raw, and parsed as its `valueType`, whose
 *  field alone is set. */
export type MlKitBarcodeValue = {
  rawValue: string | null;
  displayValue: string | null;
  /** A `ML_KIT_BARCODE_FORMATS` name. */
  format: string;
  valueType: MlKitBarcodeValueType;
  email?: MlKitBarcodeEmail | null;
  phone?: MlKitBarcodePhone | null;
  sms?: { phoneNumber: string | null; message: string | null } | null;
  url?: { title: string | null; url: string | null } | null;
  wifi?: {
    ssid: string | null;
    password: string | null;
    encryptionType: 'open' | 'wpa' | 'wep' | 'unknown';
  } | null;
  geo?: { latitude: number; longitude: number } | null;
  contactInfo?: MlKitBarcodeContact | null;
  calendarEvent?: MlKitBarcodeEvent | null;
  driverLicense?: MlKitBarcodeLicense | null;
};

/** Barcode Scanning: a code found in an image, and where. */
export type MlKitBarcode = MlKitBarcodeValue & {
  boundingBox: MlKitRect;
  /** The code's four corners, clockwise from its top-left. */
  cornerPoints: MlKitPoint[];
};

export type MlKitBarcodeOptions = {
  /** Only these `ML_KIT_BARCODE_FORMATS` (every one when left out): fewer
   *  formats scan faster. */
  formats?: readonly string[];
};

declare module './ExpoMlKitModule' {
  interface ExpoMlKitFunctions {
    detectBarcodes(
      image: ImageRef,
      formats: readonly string[] | null
    ): Promise<MlKitBarcode[]>;
  }
}

/** ML Kit Barcode Scanning alone, without `analyzeImage`'s other parts. */
export async function detectBarcodes(
  image: ImageRef,
  options: MlKitBarcodeOptions = {}
): Promise<MlKitBarcode[]> {
  return nativeFunction('detectBarcodes', 'barcodes')(
    image,
    options.formats ?? null
  );
}
