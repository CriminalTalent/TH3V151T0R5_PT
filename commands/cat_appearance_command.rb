require_relative "../utils/korean_particle"

class CatAppearanceCommand
  include KoreanParticle

  ITEM_NAME = "카피캣외형변경권"
  MAX_LENGTH = 80

  def initialize(sheet, shop_sheet_manager)
    @sheet = sheet
    @shop_sheet_manager = shop_sheet_manager
  end

  def match?(content)
    content.match?(/\[카피캣외형\/(.+?)\]/)
  end

  def execute(content:, account:, status_id:)
    return "먼저 `[등록/캐릭터명]`을 해주세요." unless @sheet.registered?(account)

    cat = @sheet.cat(account)
    return "먼저 `[카피캣등록/이름]`을 해주세요." unless cat

    cat_name = cat[:name]
    text = content.match(/\[카피캣외형\/(.+?)\]/)[1].to_s.strip

    return "묘사 문구를 입력해주세요. 예) [카피캣외형/문구]" if text.empty?
    return "묘사 문구는 #{MAX_LENGTH}자 이하로 입력해주세요." if text.length > MAX_LENGTH

    unless @sheet.remove_item(account, ITEM_NAME)
      return "소지품에 [#{ITEM_NAME}]이(가) 없습니다. 상점에서 먼저 구매해주세요."
    end

    @sheet.update_cat(account, custom_appearance: text)
    @sheet.log(account, "카피캣외형변경", text)

    <<~TEXT.strip
      #{ITEM_NAME}을(를) 사용했습니다.

      #{cat_name}의 모습이 새롭게 묘사됩니다:
      "#{text}"
    TEXT
  end
end
