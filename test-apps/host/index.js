// Host for the packages' native test bundles; the app itself does nothing.
import { registerRootComponent } from 'expo';
import { View } from 'react-native';

registerRootComponent(() => <View />);
