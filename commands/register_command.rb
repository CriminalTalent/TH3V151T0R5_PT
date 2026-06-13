class RegisterCommand
  def initialize(sheet)
    @sheet = sheet
  end

  def match?(content)
    content.match?(/\[등록\/(.+?)\]/)
  end

  def execute(content:, account:, status_id:)
    name = content.match(/\[등록\/(.+?)\]/)[1].strip

    if @sheet.register_user(account, name)
      @sheet.log(account, "등록", name)
      "#{name} 학생의 기록을 새로 만들었습니다. 카피캣도 조용히 눈을 떴군요."
    else
      "이미 등록된 학생입니다. 기록은 하나면 충분합니다."
    end
  end
end
