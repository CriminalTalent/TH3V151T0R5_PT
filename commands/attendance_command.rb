class AttendanceCommand
  LAST_ATTENDANCE_COL = 5

  def initialize(sheet)
    @sheet = sheet
  end

  def match?(content)
    content.include?("[출석]")
  end

  def execute(content:, account:, status_id:)
    return "먼저 `[등록/캐릭터명]`을 해주세요." unless @sheet.registered?(account)

    if @sheet.get_last_date(account, LAST_ATTENDANCE_COL) == @sheet.today
      return "오늘은 이미 출석했습니다. 성실함도 하루에 한 번이면 충분하죠."
    end

    @sheet.add_credit(account, 5)
    @sheet.set_last_date(account, LAST_ATTENDANCE_COL)
    @sheet.log(account, "출석", "크레딧+5")

    "출석 확인. 크레딧 5점을 지급했습니다."
  end
end
