class ProgressCommand
  def initialize(sheet)
    @sheet = sheet
  end

  def match?(content)
    content.include?("[진행참여]")
  end

  def execute(content:, account:, status_id:)
    return "먼저 `[등록/캐릭터명]`을 해주세요." unless @sheet.registered?(account)

    @sheet.add_credit(account, 50)
    @sheet.add_reputation(account, 2)
    @sheet.log(account, "진행참여", "크레딧+50/평판+2")

    "필수 진행 참여를 확인했습니다. 크레딧 50점과 평판 2점을 지급합니다."
  end
end
