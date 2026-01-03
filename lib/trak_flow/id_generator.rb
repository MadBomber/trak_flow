# frozen_string_literal: true

module TrakFlow
  # Generates hash-based IDs to prevent merge conflicts when multiple
  # agents or branches work simultaneously. The ID format is "tf-XXXX"
  # where XXXX is a truncated hash derived from a UUID.
  class IdGenerator
    DEFAULT_PREFIX = "tf"
    MIN_HASH_LENGTH = 4
    MAX_HASH_LENGTH = 8

    class << self
      def generate(prefix: DEFAULT_PREFIX, existing_ids: [], min_length: MIN_HASH_LENGTH)
        loop do
          uuid = SecureRandom.uuid
          hash = Digest::SHA256.hexdigest(uuid)[0, max_length_needed(existing_ids, min_length)]
          id = "#{prefix}-#{hash}"

          return id unless existing_ids.include?(id)
        end
      end

      def generate_child_id(parent_id, child_index)
        "#{parent_id}.#{child_index}"
      end

      def parent_id(child_id)
        return nil unless child_id.include?(".")

        child_id.split(".")[0..-2].join(".")
      end

      def valid?(id)
        return false if id.nil? || id.empty?

        id.match?(/^[a-z]+-[a-f0-9]{#{MIN_HASH_LENGTH},#{MAX_HASH_LENGTH}}(\.\d+)*$/i)
      end

      def content_hash(data)
        Digest::SHA256.hexdigest(Oj.dump(data, mode: :compat))[0, 16]
      end

      private

      def max_length_needed(existing_ids, min_length)
        return min_length if existing_ids.empty?

        [min_length, MAX_HASH_LENGTH].max
      end
    end
  end
end
