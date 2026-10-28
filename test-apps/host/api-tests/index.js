// The packages' JS API, through Expo's bridge, on a device.
import { Platform } from 'react-native';

import './mlkit.test';
import './mlkit-image.test';
import './mlkit-language.test';
import './mlkit-genai.test';
import './tools.test';

// expo-apple-ml's import throws where its module is not linked.
if (Platform.OS === 'ios') require('./apple.test');

export { runAll } from './runner';
