// Host for the packages' native test bundles; launched on its own, it runs
// the JS API suite (api-tests/) once and writes the results to Documents/
// api-results.json, which scripts/test-api-ios.sh copies off the device.
// Progress (the results so far and the test running) goes to
// api-progress.json after every test, so a crash or hang shows where. On
// Android the results also go to logcat (see below).
import { registerRootComponent } from 'expo';
import { File, Paths } from 'expo-file-system';
import { useEffect, useState } from 'react';
import { Text, View } from 'react-native';

import { runAll } from './api-tests';

function App() {
  const [status, setStatus] = useState('running');
  useEffect(() => {
    const out = new File(Paths.document, 'api-results.json');
    const progress = new File(Paths.document, 'api-progress.json');
    if (out.exists) out.delete();
    const report = (results, running) => {
      progress.write(JSON.stringify({ running, results }));
      setStatus(`running: ${running}`);
    };
    runAll(report).then((results) => {
      out.write(JSON.stringify(results));
      // One line each for scripts/test-api-android.sh, which reads logcat (a
      // release app's files are not readable from adb).
      for (const result of results)
        console.log(`API_RESULT ${JSON.stringify(result)}`);
      console.log(`API_DONE ${results.length}`);
      const failed = results.filter((r) => !r.passed).length;
      setStatus(`${results.length - failed} passed, ${failed} failed`);
    });
  }, []);
  return (
    <View style={{ flex: 1, alignItems: 'center', justifyContent: 'center' }}>
      <Text>{status}</Text>
    </View>
  );
}

registerRootComponent(App);
