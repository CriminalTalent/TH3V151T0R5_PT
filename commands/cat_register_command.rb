class CatRegisterCommand
  def initialize(sheet)
    @sheet = sheet
  end

  def match?(content)
    content.match?(/\[카피캣등록\/(.+?)\]/)
  end

  def execute(content:, account:, status_id:)
    return "먼저 `[등록/캐릭터명]`을 해주세요." unless @sheet.registered?(account)

    cat_name = content.match(/\[카피캣등록\/(.+?)\]/)[1].strip

    if cat_name.empty? || cat_name.length > 20
      return "카피캣 이름은 1~20자 사이로 정해주세요."
    end

    # 사용자 시트에서 캐릭터명 조회
    character_name = @sheet.user_name(account).to_s.strip
    character_name = account if character_name.empty?

    # 카피캣 시트에 행이 없으면 기본 행을 먼저 생성
    unless @sheet.cat_row(account)
      @sheet.create_default_cat(account, character_name)
    end

    # 캐릭터명(2열)과 카피캣명(3열)을 함께 기록
    row = @sheet.cat_row(account)
    ws  = @sheet.worksheet("카피캣")
    ws[row, 2] = character_name
    ws[row, 3] = cat_name
    ws.save

    @sheet.log(account, "카피캣등록", cat_name)

    "#{cat_name}. 좋은 이름입니다. 카피캣이 그 소리를 한 박자 늦게 따라 합니다."
  end
end
