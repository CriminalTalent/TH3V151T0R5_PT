class StatusCommand
  def initialize(sheet)
    @sheet = sheet
  end

  def match?(content)
    content.include?("[상태]")
  end

  def execute(content:, account:, status_id:)
    return "먼저 `[등록/캐릭터명]`을 해주세요." unless @sheet.registered?(account)

    name   = @sheet.user_name(account)
    credit = @sheet.get_credit(account)
    pts    = @sheet.get_stat_points(account)
    st     = @sheet.stats(account)

    <<~TEXT.strip
      #{name} 학생의 현재 기록입니다.

      크레딧: #{credit}
      스탯 포인트 잔여: #{pts}pt

      건강: #{st["건강"]}
      마법능력: #{st["마법능력"]}
      인내: #{st["인내"]}
      속도: #{st["속도"]}
      기술: #{st["기술"]}
      행운: #{st["행운"]}
    TEXT
  end
end
