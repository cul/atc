interface SessionInfo {
  signOutPath: string;
}

let cachedSessionInfo: SessionInfo | null = null;

const readSessionInfo = (): SessionInfo => {
  if (!cachedSessionInfo) {
    const rootEl = document.getElementById('s3-browser-app');
    cachedSessionInfo = { signOutPath: rootEl?.dataset.signOutPath };
  }
  return cachedSessionInfo;
};

export const useSessionInfo = () => {
  return readSessionInfo();
};
