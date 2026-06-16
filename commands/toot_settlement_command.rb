class TootSettlementCommand
  CREDIT_PER_100_TOOTS = 5

  def initialize(sheet)
    @sheet = sheet
  end

  def match?(content)
    content.match?(/\[툿정산\/(\d+)\]/)
  end

  def execute(content:, account:, status_id:)
    return "먼저 `[등록/캐릭터명]`을 해주세요." unless @sheet.registered?(account)

    current_count = content.match(/\[툿정산\/(\d+)\]/)[1].to_i
    base_count    = @sheet.get_toot_base(account)

    if current_count < base_count
      return "현재 툿 수가 이전 정산 기준보다 낮습니다.\n이전 기준: #{base_count}\n입력값: #{current_count}"
    end

    diff   = current_count - base_count
    units  = diff / 100
    reward = units * CREDIT_PER_100_TOOTS

    if reward <= 0
      @sheet.set_toot_total(account, current_count)
      return "정산 가능한 증가량이 부족합니다.\n이전 기준: #{base_count}\n현재 툿 수: #{current_count}\n증가량: #{diff}\n100툿당 #{CREDIT_PER_100_TOOTS}크레딧입니다."
    end

    new_base = base_count + (units * 100)

    @sheet.add_credit(account, reward)
    @sheet.set_toot_total(account, current_count)
    @sheet.set_toot_base(account, new_base)
    @sheet.log(account, "툿정산", "#{base_count}→#{current_count}/증가#{diff}/#{reward}크레딧")

    <<~TEXT.strip
      툿 정산 완료.

      이전 기준: #{base_count}
      현재 툿 수: #{current_count}
      증가량: #{diff}

      크레딧 +#{reward}
      새 정산 기준: #{new_base}
    TEXT
  end
end
