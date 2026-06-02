import * as React from 'react';
import { AppRouter } from './router';
import { AppProvider } from './provider';

const App = () => {
  return (
    <React.StrictMode>
      <AppProvider>
        <AppRouter />
      </AppProvider>
    </React.StrictMode>
  );
};

export default App;
