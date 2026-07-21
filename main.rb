$stdout.sync = true
$stderr.sync = true
require "dotenv/load"
require_relative "./mastodon_client"
require_relative "./sheet_manager"
require_relative "./command_parser"

class Main
  LAST_ID_FILE = File.expand_path(
    "last_mention_id.txt",
    __dir__
  ).freeze

  def initialize
    @mastodon = MastodonClient.new(
      base_url: ENV.fetch("MASTODON_BASE_URL"),
      token:    ENV.fetch("MASTODON_ACCESS_TOKEN")
    )

    @sheet  = SheetManager.new
    @parser = CommandParser.new(@sheet)
  end

  def run
    puts "[VISITORS_CARE] bot started."
    puts "[LAST ID FILE] #{LAST_ID_FILE}"

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

    mentions = @mastodon.mentions(
      since_id: last_id
    )

    return if mentions.empty?

    # Mastodon 알림은 보통 최신순으로 반환되므로
    # 오래된 알림부터 순서대로 처리한다.
    mentions.reverse_each do |mention|
      process_mention(mention)
    end
  end

  def process_mention(mention)
    notification_id = mention["id"].to_s
    status_id       = mention.dig("status", "id").to_s
    account         = mention.dig("account", "acct").to_s.strip

    unless valid_id?(notification_id)
      warn(
        "[MENTION SKIP] 잘못된 notification_id=" \
        "#{notification_id.inspect}"
      )
      return
    end

    if status_id.empty? || account.empty?
      warn(
        "[MENTION SKIP] notification_id=#{notification_id} " \
        "status_id=#{status_id.inspect} " \
        "account=#{account.inspect}"
      )

      # 구조가 잘못된 알림을 계속 다시 읽지 않도록 넘긴다.
      write_last_id(notification_id)
      return
    end

    content = @mastodon.clean_content(mention)

    puts(
      "[MENTION] notification_id=#{notification_id} " \
      "status_id=#{status_id} account=#{account}: #{content}"
    )

    command_processed = false

    begin
      response = @parser.call(
        content:   content,
        account:   account,
        status_id: status_id
      )

      # 여기까지 왔다면 명령 파서 실행은 종료된 것이다.
      # 인식되지 않은 명령으로 nil이 반환된 경우도 처리 완료로 본다.
      command_processed = true

      post_response(
        account:   account,
        content:   content,
        status_id: status_id,
        response:  response
      )
    rescue => e
      warn(
        "[MENTION ERROR] notification_id=#{notification_id} " \
        "status_id=#{status_id} account=#{account} " \
        "#{e.class}: #{e.message}"
      )
      warn e.backtrace.first(5).join("\n")
    ensure
      # 명령 처리가 끝났다면 답글 전송 실패 여부와 관계없이
      # 알림 ID를 기록한다.
      #
      # 예:
      # 1. 툿정산 시트 저장 성공
      # 2. Mastodon 답글 전송 실패
      # 3. last_id 미저장
      # 4. 같은 툿정산 멘션 재처리
      #
      # 위 상황을 방지한다.
      if command_processed
        unless write_last_id(notification_id)
          warn(
            "[LAST ID WARNING] 처리 완료 알림의 ID 저장 실패 " \
            "notification_id=#{notification_id}"
          )
        end
      end
    end
  end

  def post_response(account:, content:, status_id:, response:)
    return if response.nil?
    return if response.to_s.strip.empty?

    visibility =
      if content.match?(/\[툿정산\/\d+\]/)
        "direct"
      else
        "unlisted"
      end

    @mastodon.post_status(
      "@#{account} #{response}",
      reply_to_id: status_id,
      visibility:  visibility
    )

    puts(
      "[REPLY COMPLETE] status_id=#{status_id} " \
      "account=#{account} visibility=#{visibility}"
    )
  rescue => e
    # 답글 전송 실패는 이미 완료된 명령을 다시 실행할 이유가 아니다.
    # 특히 툿정산처럼 시트 값을 변경하는 명령은 재처리를 막아야 한다.
    warn(
      "[REPLY ERROR] status_id=#{status_id} account=#{account} " \
      "#{e.class}: #{e.message}"
    )
    warn e.backtrace.first(5).join("\n")
  end

  def read_last_id
    return nil unless File.exist?(LAST_ID_FILE)

    value = File.read(LAST_ID_FILE).to_s.strip
    return nil unless valid_id?(value)

    value
  rescue => e
    warn "[LAST ID READ ERROR] #{e.class}: #{e.message}"
    nil
  end

  def write_last_id(id)
    value = id.to_s.strip
    return false unless valid_id?(value)

    temp_path = "#{LAST_ID_FILE}.tmp"

    File.write(temp_path, value)
    File.rename(temp_path, LAST_ID_FILE)

    true
  rescue => e
    warn(
      "[LAST ID WRITE ERROR] id=#{value.inspect} " \
      "#{e.class}: #{e.message}"
    )

    begin
      File.delete(temp_path) if File.exist?(temp_path)
    rescue
      nil
    end

    false
  end

  def valid_id?(value)
    value.to_s.match?(/\A\d+\z/)
  end
end

Main.new.run
