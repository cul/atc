// POST, PUT, PATCH, and DELETE requests require the csrf token to be included in headers
export const getCsrfToken = () => {
  return (document.querySelector('meta[name="csrf-token"]') as HTMLMetaElement)?.content;
};

export const getCsrfParam = () => {
  return (document.querySelector('meta[name="csrf-param"]') as HTMLMetaElement)?.content;
};
