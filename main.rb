require "dotenv/load"
require_relative "./mastodon_client"
require_relative "./sheet_manager"
require_relative "./command_parser"

class Main
  LAST_ID_FILE = "last_mention_id.txt"

  def initialize
    @mastodon = MastodonClient.new
    @sheet = SheetManager.new
    @parser = CommandParser.new(@sheet)
  end

  def run
    puts "[VISITORS_CARE] bot started."

    loop do
      begin
        process_mentions
      rescue => e
        warn "[ERROR] #{e.class}: #{e.message}"
        warn e.backtrace.first(5).join("\n")
      end

      sleep 15
    end
  end

  private

  def process_mentions
    last_id = read_last_id
    mentions = @mastodon.mentions(since_id: last_id)

    return if mentions.empty?

    mentions.reverse_each do |mention|
      content = @mastodon.clean_content(mention)
      account = mention.account.acct
      status_id = mention.status.id.to_s

      puts "[MENTION] #{account}: #{content}"

      response = @parser.call(
        content: content,
        account: account,
        status_id: status_id
      )

      @mastodon.reply(status_id, "@#{account} #{response}") if response
      write_last_id(mention.id)
    end
  end

  def read_last_id
    return nil unless File.exist?(LAST_ID_FILE)

    File.read(LAST_ID_FILE).strip
  end

  def write_last_id(id)
    File.write(LAST_ID_FILE, id.to_s)
  end
end

Main.new.run
