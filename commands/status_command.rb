class StatusCommand
  def initialize(sheet)
    @sheet = sheet
  end

  def match?(content)
    content.include?("[상태]")
  end

  def execute(content:, account:, status_id:)
    return "먼저 `[등록/캐릭터명]`을 해주세요." unless @sheet.registered?(account)

    name = @sheet.user_name(account)
    credit = @sheet.get_credit(account)
    stats = @sheet.stats(account)

    <<~TEXT.strip
      #{name} 학생의 현재 기록입니다.

      크레딧: #{credit}

      건강: #{stats["건강"]}
      마법능력: #{stats["마법능력"]}
      내구도: #{stats["내구도"]}
      민첩: #{stats["민첩"]}
      기술: #{stats["기술"]}
      행운: #{stats["행운"]}
    TEXT
  end
end
