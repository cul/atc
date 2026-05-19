export interface Bucket {
  name: string;
  description: string;
}

export interface S3Object {
  key: string;
  size: number;
  lastModified: string;
  storageClass: string;
}

export interface S3Prefix {
  prefix: string;
}

export interface BucketContentsResponse {
  objects: S3Object[];
  folders: string[];
}

export type ObjectDetails = {
  key: string;
  bucket: string;
  size: number;
  contentType: string;
  lastModified: string;
  storageClass: string;
  archiveStatus: string | null;
  restoreStatus: string | null;
};

// A row type for the bucket contents table.
// Each item is either a folder or an object, distinguished by the `type` field.
export type BucketItem =
  | {
    type: 'folder';
    name: string;
    fullPath: string;
  }
  | {
    type: 'object';
    name: string;
    fullPath: string;
    size: number;
    lastModified: string;
    storageClass: string;
  };