require_relative "../utils/korean_particle"

class CatRenameCommand
  include KoreanParticle

  ITEM_NAME = "카피캣이름변경권"
  MAX_LENGTH = 12

  def initialize(sheet, shop_sheet_manager)
    @sheet = sheet
    @shop_sheet_manager = shop_sheet_manager
  end

  def match?(content)
    content.match?(/\[카피캣이름\/(.+?)\]/)
  end

  def execute(content:, account:, status_id:)
    return "먼저 `[등록/캐릭터명]`을 해주세요." unless @sheet.registered?(account)

    cat = @sheet.cat(account)
    return "먼저 `[카피캣등록/이름]`을 해주세요." unless cat

    new_name = content.match(/\[카피캣이름\/(.+?)\]/)[1].to_s.strip

    return "새 이름을 입력해주세요. 예) [카피캣이름/새이름]" if new_name.empty?
    return "이름은 #{MAX_LENGTH}자 이하로 입력해주세요." if new_name.length > MAX_LENGTH

    old_name = cat[:name]

    unless @sheet.remove_item(account, ITEM_NAME)
      return "소지품에 [#{ITEM_NAME}]이(가) 없습니다. 상점에서 먼저 구매해주세요."
    end

    @sheet.update_cat(account, name: new_name)
    @sheet.log(account, "카피캣이름변경", "#{old_name} → #{new_name}")

    <<~TEXT.strip
      #{ITEM_NAME}을(를) 사용했습니다.

      #{old_name}%{이} 이제 #{new_name}(으)로 불립니다.
    TEXT
      .sub("%{이}", i_ga(old_name))
  end
end
