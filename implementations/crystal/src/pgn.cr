module PGN
  RESULTS = ["1-0", "0-1", "1/2-1/2", "*"]

  def self.extract_moves(content : String) : Array(String)
    move_text = Array(String).new

    content.each_line do |line|
      stripped = line.strip
      next if stripped.empty?
      next if stripped.starts_with?('[')
      move_text << stripped
    end

    text = move_text.join(" ")
    text = text.gsub(/\{[^}]*\}/, " ")
    text = text.gsub(/\([^)]*\)/, " ")
    text = text.gsub(/;[^\r\n]*/, " ")

    moves = Array(String).new
    text.split(/\s+/).each do |raw_token|
      token = raw_token.strip
      next if token.empty?
      next if token.starts_with?('$')
      next if RESULTS.includes?(token)
      next if token.matches?(/^\d+\.(?:\.\.)?$/)

      token = token.gsub(/^\d+\.(?:\.\.)?/, "")
      token = token.strip

      next if token.empty?
      next if RESULTS.includes?(token)

      moves << token
    end

    moves
  end
end
