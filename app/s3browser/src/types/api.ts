export interface Bucket {
  name: string;
  description?: string;
}
 
export interface S3Object {
  key: string;
  size: number;
  lastModified: string;
  etag?: string;
}
 
export interface S3Prefix {
  prefix: string;
}

// Temp
export interface BucketContentsResponse {
  objects: S3Object[];
  commonPrefixes: S3Prefix[];
}
 