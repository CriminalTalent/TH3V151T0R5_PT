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

    count  = content.match(/\[툿정산\/(\d+)\]/)[1].to_i
    units  = count / 100
    reward = units * CREDIT_PER_100_TOOTS

    if reward <= 0
      return "정산 가능한 툿 수가 부족합니다. 100툿당 #{CREDIT_PER_100_TOOTS}크레딧입니다."
    end

    @sheet.add_credit(account, reward)
    @sheet.log(account, "툿정산", "#{count}툿/#{reward}크레딧")

    "#{count}툿 정산 완료. 크레딧 #{reward}점을 지급했습니다."
  end
end
