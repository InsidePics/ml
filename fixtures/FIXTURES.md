# Fixtures

Test inputs shared by every package's native tests. They are not covered by
the repository's MIT licence: each file keeps its own licence, below.

## Sources

Every image is from Wikimedia Commons. "Adapted" means centre-cropped to the
size shown and saved as an sRGB JPEG.

| File            | Source                                                                                                                                                                          | Author                                         | Licence                                                                                    | Changes          |
| --------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------- | ------------------------------------------------------------------------------------------ | ---------------- |
| `text.jpg`      | [Warning Notice](https://commons.wikimedia.org/wiki/File:Warning_Notice_-_geograph.org.uk_-_1462251.jpg) (also [Geograph 1462251](https://www.geograph.org.uk/photo/1462251))   | Bill Rowley                                    | [CC BY-SA 2.0](https://creativecommons.org/licenses/by-sa/2.0/)                            | none             |
| `barcode.jpg`   | [EAN-Obst](https://commons.wikimedia.org/wiki/File:EAN-Obst.jpg)                                                                                                                | Raimond Spekking (scan of a REWE label)        | Public domain ([PD-ineligible](https://commons.wikimedia.org/wiki/Template:PD-ineligible)) | none             |
| `face.jpg`      | [Headshot Smile II](https://commons.wikimedia.org/wiki/File:Headshot_Smile_II.png)                                                                                              | Marcorossi2                                    | [CC BY-SA 4.0](https://creativecommons.org/licenses/by-sa/4.0/)                            | adapted, 400×600 |
| `body.jpg`      | [Energy Yoga Teacher Training](https://commons.wikimedia.org/wiki/File:Energy_Yoga_Teacher_Training_with_David_Scott_Yglesias.jpg)                                              | David Scott Yglesias                           | [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/)                                  | adapted, 640×427 |
| `hand.jpg`      | [Palm](<https://commons.wikimedia.org/wiki/File:Palm_(5795924936).jpg>)                                                                                                         | halfrain                                       | [CC BY-SA 2.0](https://creativecommons.org/licenses/by-sa/2.0/)                            | adapted, 640×427 |
| `animal.jpg`    | [German Shepherd Dog](https://commons.wikimedia.org/wiki/File:20110425_German_Shepherd_Dog_8505.jpg)                                                                            | Jakub Hałun                                    | [CC BY-SA 4.0](https://creativecommons.org/licenses/by-sa/4.0/)                            | adapted, 640×427 |
| `landscape.jpg` | [Eagle River Park, Anchorage](https://commons.wikimedia.org/wiki/File:Parque_Eagle_River,_Anchorage,_Alaska,_Estados_Unidos,_2017-09-01,_DD_02.jpg)                             | Diego Delso                                    | [CC BY-SA 4.0](https://creativecommons.org/licenses/by-sa/4.0/)                            | adapted, 400×267 |
| `document.jpg`  | [Letter to Eleanor R. Webster from Pearl Chen, 1974](https://commons.wikimedia.org/wiki/File:Letter_and_envelope_to_Eleanor_R._Webster_from_Pearl_Chen,_September_16,_1974.jpg) | Pearl Chen; scan by Wellesley College Archives | Public domain ([PD-ROC-exempt](https://commons.wikimedia.org/wiki/Template:PD-ROC-exempt)) | adapted, 640×427 |
| `invoice.jpg`   | [LEGO Store receipt, Rotterdam](<https://commons.wikimedia.org/wiki/File:LEGO_Store_receipt,_Hillegersberg,_Rotterdam_(2023)_02.jpg>)                                           | Donald Trung Quoc Don                          | [CC BY-SA 4.0](https://creativecommons.org/licenses/by-sa/4.0/)                            | adapted, 640×377 |
| `qrcode.jpg`    | [Munzee QR Code Sticker](<https://commons.wikimedia.org/wiki/File:Munzee_Scavenger_Hunt_Game_QR_Code_Sticker_-_Spring_Lake_Park_Reserve,_Minnesota_(28519465928).jpg>)          | Tony Webster                                   | [CC BY 2.0](https://creativecommons.org/licenses/by/2.0/)                                  | adapted, 400×267 |

## Made here

- `face-orientation-{1,3,6,8}.{jpg,heic}`: `face.jpg` stored turned and
  tagged to be shown upright (`swift scripts/make-orientation-fixtures.swift`).
  Same licence as `face.jpg`.
- `speech.m4a`: macOS `say`, "Hello world. This is a test of on-device speech
  recognition. The quick brown fox jumps over the lazy dog."
- `expected/model-inputs.json`: what the InsidePics app's former model-input
  code (expo-model-inputs) built from each fixture, on macOS.
- `expected/decode-grid.json`: the iOS decode of each fixture as a 16×16
  colour grid (`RECORD_FIXTURE=1 pnpm --filter @insidepics/expo-image-ml-tools test:swift`).

A replaced fixture means re-recording both `expected/` files and updating any
test that names what the image shows (the eye positions in the face tests,
the barcode value, the sign's words).
