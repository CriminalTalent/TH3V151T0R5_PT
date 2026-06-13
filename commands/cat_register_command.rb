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

    @sheet.set_cat_name(account, cat_name)
    @sheet.log(account, "카피캣등록", cat_name)

    "#{cat_name}. 좋은 이름입니다. 카피캣이 그 소리를 한 박자 늦게 따라 합니다."
  end
end
