module Book
  struct Entry
    getter move : String
    getter weight : Int32

    def initialize(@move : String, @weight : Int32)
    end
  end

  def self.position_key_from_fen(fen : String) : String
    parts = fen.strip.split(/\s+/)
    return parts[0, 4].join(" ") if parts.size >= 4
    fen.strip
  end

  def self.parse_entries(content : String) : {Hash(String, Array(Entry)), Int32}
    entries = Hash(String, Array(Entry)).new
    total_entries = 0

    content.each_line.with_index(1) do |raw, line_number|
      line = raw.strip
      next if line.empty? || line.starts_with?('#')

      parts = line.split("->", 2)
      raise "line #{line_number}: expected '<fen> -> <move> [weight]'" unless parts.size == 2

      key = position_key_from_fen(parts[0])
      raise "line #{line_number}: empty position key" if key.empty?

      rhs_fields = parts[1].strip.split(/\s+/)
      raise "line #{line_number}: missing move" if rhs_fields.empty?

      move = rhs_fields[0].downcase
      raise "line #{line_number}: invalid move #{move.inspect}" unless move.matches?(/^[a-h][1-8][a-h][1-8][qrbn]?$/)

      weight = 1
      if rhs_fields.size > 1
        parsed_weight = rhs_fields[1].to_i?
        raise "line #{line_number}: invalid weight #{rhs_fields[1].inspect}" if parsed_weight.nil?
        raise "line #{line_number}: weight must be > 0" if parsed_weight <= 0
        weight = parsed_weight
      end

      bucket = entries[key]? || Array(Entry).new
      bucket << Entry.new(move, weight)
      entries[key] = bucket
      total_entries += 1
    end

    {entries, total_entries}
  end
end
