#coding: utf-8
require 'pry'
require 'twitter'
require 'yaml'
require 'active_record'
require 'date'
require './twitter_connect.rb'

class TwitterReminder < TwitterConnect
  def initialize identity, opt = nil
    db = YAML.load_file('db/config/database.yml')
    ActiveRecord::Base.establish_connection(db["db"]["development"])
    super(identity, opt)
    @reminder_stacks = Array.new
  end

  def stream
    regexp_name = /^@#{@user_screen_name}\supdate_name\s(.+)$/
    regexp_text = /^@#{@user_screen_name}\s(.+)$/
    $update_name_available = true

    @client.user do |status|
      if status.is_a?(Twitter::Tweet)

        if status.in_reply_to_screen_name == @user_screen_name
          # update_name
          if $update_name_available
            if status.text.match(regexp_name)
              update_name($1, status.user)
            end
          end

          # reminder
          if status.user.screen_name == @user_screen_name
            # 自分自身から自分自身へのリプライの場合
            text = status.text.match(regexp_text)[1]
            semantic_process(text, status.user)
          end
        end
      end

      if status.is_a?(Twitter::DirectMessage)
        semantic_process(status.text)
      end
    end
  end

  def semantic_process(text, user = nil)
    regexp_rd = /^rd:\s(.+)\s(.+)$/
    regexp_kc = /^kc:\s(.+)\s(.+)$/
    regexp_cmd = /^(\$|cmd:)\s(.+)\s(.+)$/

    case text
    when regexp_rd
      reminder_process($1, $2)
    when regexp_kc
      puts 'kc'
    when regexp_cmd
      command_process($2, $3)
    end
  end

  def reminder_process(remind_time, notice_text)
    # remind_time: リマインダーの時間指定
    # notice_text: リマインダのコメント

    regexp_time = /^(\d{1,2}):(\d{2})$/
    regexp_hour = /^(\d+)h$/
    regexp_min = /^(\d+)m$/
    regexp_hybrid = /^(\d+)h(\d+)m/
    case remind_time
    when regexp_time
      h = $1.to_i
      m = $2.to_i
      date = DateTime.now

      #dateに差し引きで指定の時間に変更(時、分のみ変更)
      date += Rational(h - date.hour, 24)
      date += Rational(m - date.minute, 24*60)
      date -= Rational(date.second, 24*60*60) # 差し引きで0秒に指定

      # 当日中であるか明日であるかを判定し、明日の場合は1(day)を加算
      date += 1 if (h < date.hour) || (h == date.hour && m < date.minute)

      notice_date = "#{h}:#{m}"

    when regexp_hour
      hour = $1.to_i
      date = date_calc(hour, 0)
      notice_date = "#{hour}時間後"
    when regexp_min
      minute = $1.to_i
      date = date_calc(0, minute)
      notice_date = "#{minute}分後"
    when regexp_hybrid
      hour = $1.to_i
      minute = $2.to_i
      date = date_calc(hour, minute)
      notice_date = "#{hour}時間#{minute}分後"
    end

    # @reminder_stacks(Array)にHash形式でtextとdate(DateTime)を追加し、date順にsortする
    @reminder_stacks << Hash[text: notice_text, date: date]
    @reminder_stacks.sort_by!{|elm| elm[:date]}
    @thread.run
    puts 'Reminder Added'
    text = "リマインダーを設定しました: #{notice_text} - #{notice_date}"
    puts text
    @rest_client.update("D #{@user_screen_name} #{text}")
  end

  def date_calc(hour = 0, minute = 0)
    date = DateTime.now + Rational(hour, 24) + Rational(minute, 24*60)
    return date
  end


  def command_process(target, cmd)
    case target
    when /rd|reminder/
      cmd_reminder(cmd)
    when 'update_name'
      cmd_update_name(cmd)
    when 'kancolle'
      puts 'cmd_kancolle'
    end
  end

  def cmd_reminder(cmd, opt = nil)
    case cmd
    when 'ls'
      @reminder_stacks.each do |stack|
        puts "#{stack[:text]} - #{stack[:date]}"
      end
      puts 'nothing is reminderd' if @reminder_stacks.empty?
    end
  end

  def cmd_update_name(cmd, opt = nil)
    case cmd
    when 'start'
      $update_name_available = true
    when 'kill'
      $update_name_available = false
    end
  end


  def update_name(updated_name, user, opt = nil)
    ng_regexp = /ニフティ|犯罪|セックス|ホモ|ロリコン|ペド|内定|留年|オナニー|裸|ちんこ|ちんちん|おちん|チンコ|まんこ|マンコ|蓮爾'/
    before_name = @rest_client.user.name
    begin
      if updated_name.match(ng_regexp)
        @rest_client.update("@#{user.screen_name} NGワードが含まれています")
      else
        @rest_client.update_profile(name: updated_name)
        notice = "@#{user.screen_name}(#{user.name}))により改名されました: #{before_name} => #{updated_name}"
        puts notice
        @rest_client.update(notice)
      end
    rescue
      puts 'update_name denied.'
      notice = "@#{user.screen_name} 失敗しました: #{updated_name}"
      if notice.length < 140
        @rest_client.update("@#{user.screen_name} 失敗しました: #{updated_name}")
      else
        @rest_client.update("@#{user.screen_name} 失敗しました")
      end
    end
  end


  def observer
    @thread = Thread.new do
      loop do
        unless @reminder_stacks.empty?
          # スタックが存在する場合ははじめのスタックについて処理しその後ループに戻る
          gap = @reminder_stacks[0][:date] - DateTime.now
          if gap < Rational(1, 24*60*60)
            notice_text = "#{@reminder_stacks[0][:text]}"
            puts notice_text
            @rest_client.update("D #{@user_screen_name} #{notice_text}")
            @reminder_stacks.delete_at(0)
            break
          else
            # 最初のタスクの実行時間でない場合、差分の時間sleepする
            # タスクが追加された場合にはsteamからrunされ、再度最初のタスクについて確認処理をする
            puts 'sleep'
            sleep_time = (gap * 24*60*60).to_i
            puts "rest: #{sleep_time}"
            sleep(sleep_time)
            # streamからのrun信号を受けて再開する
            puts 'awake'
          end
        else
          # スタックがない場合は、スタック追加によりstreamからrunされるまで停止する
          puts 'sleep'
          Thread.stop
          # streamからのrun信号を受けて再開する
          puts 'awake'
        end
      end
    end
  end

  def test # Commandline Test
    loop do
      print 'text: '
      text = gets.chomp
      semantic_process(text)
    end
  end
end

@tr = TwitterReminder.new('wakotsu_bot')

# @reminder_stacks = Array.new
@tr.observer
# @tr.stream
@tr.test


