# encoding: UTF-8
# 재시작 전 사전 점검. 실패 항목이 있으면 pm2 restart 하지 말 것.
require "fileutils"

ROOT = File.expand_path(__dir__)
@failures = []
@passes = 0

def check(label)
  ok = yield
  if ok
    @passes += 1
    puts "  OK   #{label}"
  else
    @failures << label
    puts "  FAIL #{label}"
  end
rescue => e
  @failures << "#{label} (#{e.class}: #{e.message})"
  puts "  FAIL #{label} - #{e.class}: #{e.message}"
end

puts "=" * 60
puts "TH3V151T0R5_PT preflight check"
puts "=" * 60

# 1. 필수 파일 존재
puts "\n[1] 필수 파일"
%w[
  main.rb
  sheet_manager.rb
  mastodon_client.rb
  command_parser.rb
  ecosystem.config.js
  Gemfile
  Gemfile.lock
  .env
].each do |f|
  check(f) { File.exist?(File.join(ROOT, f)) }
end

# 2. command_parser.rb의 require_relative 대상 파일 실재 여부
puts "\n[2] command_parser require 대상"
parser_path = File.join(ROOT, "command_parser.rb")
if File.exist?(parser_path)
  targets = File.read(parser_path).scan(/require_relative\s+["'](.+?)["']/).flatten
  if targets.empty?
    puts "  WARN require_relative 없음"
  end
  targets.each do |t|
    rel = t.end_with?(".rb") ? t : "#{t}.rb"
    check(rel) { File.exist?(File.expand_path(rel, ROOT)) }
  end
else
  @failures << "command_parser.rb 없음"
end

# 3. 루비 문법 검사
puts "\n[3] 문법 검사"
Dir.glob(File.join(ROOT, "**", "*.rb")).reject { |p|
  p.include?("/vendor/") || p.include?("/.git/") || File.basename(p) == File.basename(__FILE__)
}.sort.each do |path|
  rel = path.sub("#{ROOT}/", "")
  check(rel) { system("ruby", "-c", path, out: File::NULL, err: File::NULL) }
end

# 4. 환경변수
puts "\n[4] 환경변수 (.env)"
env_path = File.join(ROOT, ".env")
if File.exist?(env_path)
  env_keys = File.readlines(env_path).map { |l|
    l.strip
  }.reject { |l|
    l.empty? || l.start_with?("#")
  }.map { |l| l.split("=", 2).first.to_s.strip }

  %w[MASTODON_BASE_URL MASTODON_ACCESS_TOKEN].each do |k|
    check(k) { env_keys.include?(k) }
  end
else
  @failures << ".env 없음"
end

# 5. 인증 파일
puts "\n[5] 인증 파일"
cred = Dir.glob(File.join(ROOT, "*.json"))
check("구글 인증 json 존재") { !cred.empty? }

# 6. ecosystem.config.js interpreter none
puts "\n[6] PM2 설정"
eco = File.join(ROOT, "ecosystem.config.js")
if File.exist?(eco)
  body = File.read(eco)
  check("interpreter: none") { body.match?(/interpreter\s*:\s*["']none["']/) }
  check("앱 이름 pt_bot") { body.include?("pt_bot") }
else
  @failures << "ecosystem.config.js 없음"
end

# 7. last_mention_id.txt
puts "\n[7] last_mention_id"
last_id_path = File.join(ROOT, "last_mention_id.txt")
check("last_mention_id.txt 존재") { File.exist?(last_id_path) }
if File.exist?(last_id_path)
  check("last_mention_id 값이 숫자") { File.read(last_id_path).strip.match?(/\A\d+\z/) }
end

# 8. Gemfile 버전 고정
puts "\n[8] Gemfile 고정 버전"
gemfile = File.join(ROOT, "Gemfile")
if File.exist?(gemfile)
  body = File.read(gemfile)
  check("google_drive 3.0.7") { body.match?(/google_drive.*3\.0\.7/) }
  check("googleauth 0.16") { body.match?(/googleauth.*0\.16/) }
else
  @failures << "Gemfile 없음"
end

# 9. main.rb 금지 require
puts "\n[9] main.rb require 규칙"
main_path = File.join(ROOT, "main.rb")
if File.exist?(main_path)
  main_body = File.read(main_path)
  check("google/apis/sheets_v4 직접 require 없음") {
    !main_body.match?(/^\s*require\s+["']google\/apis\/sheets_v4["']/)
  }
  check("googleauth 직접 require 없음") {
    !main_body.match?(/^\s*require\s+["']googleauth["']/)
  }
end

# 10. 기숙사 점수 캐시 규칙
puts "\n[10] 기숙사 점수 읽기 규칙"
sm_path = File.join(ROOT, "sheet_manager.rb")
if File.exist?(sm_path)
  sm_body = File.read(sm_path)
  check("add_house_score가 fresh_worksheet 사용") {
    seg = sm_body[/def add_house_score\b.*?\n  end/m].to_s
    seg.include?("fresh_worksheet(HOUSE_SHEET)")
  }
  check("add_house_score_all이 fresh_worksheet 사용") {
    seg = sm_body[/def add_house_score_all\b.*?\n  end/m].to_s
    seg.include?("fresh_worksheet(HOUSE_SHEET)")
  }
  check("log_house_score 정의됨") { sm_body.include?("def log_house_score") }
  check("HOUSE_LOG_SHEET 상수 존재") { sm_body.include?("HOUSE_LOG_SHEET") }
end

# 11. SheetManager 단일 인스턴스
puts "\n[11] SheetManager 인스턴스"
if File.exist?(main_path)
  main_body = File.read(main_path)
  check("SheetManager.new 1회만 호출") {
    main_body.scan(/SheetManager\.new/).size == 1
  }
end

# 결과
puts "\n" + "=" * 60
if @failures.empty?
  puts "통과 #{@passes}건 / 실패 0건 — 재시작 가능"
  puts "=" * 60
  exit 0
else
  puts "통과 #{@passes}건 / 실패 #{@failures.size}건 — 재시작 금지"
  @failures.each { |f| puts "  - #{f}" }
  puts "=" * 60
  exit 1
end
