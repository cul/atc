# frozen_string_literal: true

module Atc::Exceptions
  class AtcError < StandardError; end
  class ProviderFixityCheckNotFound < AtcError; end
  class TransferError < AtcError; end
  class ObjectExists < AtcError; end
  class StorageProviderMappingNotFound < AtcError; end
  class RemoteFixityCheckTimeout < AtcError; end
  class PollingWaitTimeoutError < AtcError; end

  class DirectoryLoadError < AtcError; end
  class UnreadableFiles < DirectoryLoadError; end
  class InvalidAip < DirectoryLoadError; end
  class MissingAipChecksums < DirectoryLoadError; end
end
