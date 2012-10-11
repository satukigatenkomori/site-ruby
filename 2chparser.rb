# -*- mode: ruby; coding: utf-8 -*-

require 'open-uri'
require 'kconv'

$KCODE = 'utf8'

module Psycho
  module Util

    class PostingModel
      attr_accessor :serial, :number, :hundle, :email, :posted, :id, :contents, :parents, :children, :nest
      def initialize(params={})
        @serial   = params[:serial]
        @number   = params[:number]
        @hundle   = params[:hundle]
        @email    = params[:email]
        @posted   = params[:posted]
        @id       = params[:id]
        @contents = params[:contents]
        @parents  = params[:parents]
        @children = params[:children] ? params[:children] : Array.new
        @nest     = params[:nest] ? params[:nest] : 0
      end
      # for template
      def to_liquid
        {
          'number'   => @number,
          'hundle'   => @hundle,
          'email'    => @email,
          'posted'   => @posted,
          'id'       => @id,
          'contents' => @contents,
          'nest'     => @nest
        }
      end
    end

    class ThreadModel
      attr_accessor :id, :subject, :owner
      def initialize(params={})
        @id = params[:id]
        @subject = params[:subject]
        @owner = params[:owner]
      end
      # for template
      def to_liquid
        {
          'id'      => @id,
          'subject' => @subject,
          'owner'   => @owner
        }
      end
    end

    module_function

    def getChild(articles, article, nest=0)
      article.nest = nest
      children = [article]
      article.children.sort.each do |child_number|
        children.concat(getChild(articles, articles[child_number-1], nest+1))
      end
      children
    end

    def PostingSummary(dat, effective_posts=1000)

      thread = nil
      articles = []

      open(dat) do |file|
        number = 1
        while line = file.gets
          #break if number >= 1001
          break if number > effective_posts
          arr = line.toutf8.strip.split('<>')
          hundle = arr[0].strip
          if number == 1
            r = dat.match(/^https?:\/\/.+?\/dat\/(\d+)\.dat/)
            thread = ThreadModel.new(:subject => arr[4].strip, :owner => hundle, :id => r[0] ? r[1] : 0)
          end
          posted_and_id = arr[2].strip.split

          parents = []
          arr[3].strip.scan(/&gt;&gt;\s*([\d]+)/) do |parent_number_arr|
            if number > parent_number_arr[0].to_i
              parents << parent_number_arr[0].to_i
              tmp = articles.select do |p|
                p.number == parent_number_arr[0].to_i
              end
              tmp.each do |c|
                c.children << number
              end
            end
          end

          contents = arr[3].strip.gsub(/sssp:\/\//, 'http://').gsub(/<\/?b>/, '').gsub(/(?:<a\s+href=\"\.\.[^>]+>)(?:&gt;&gt;)\s*(\d+)(?:<\/a>)/, '<a href="#\\1">&gt;&gt;\\1</a>')

          links = contents.scan(/h?ttps?:\/\/[-_.!~*\'()a-zA-Z0-9;\/?:\@&=+\$,%#]+/)
          contents.gsub!(/(h?ttps?:\/\/[-_.!~*\'()a-zA-Z0-9;\/?:\@&=+\$,%#]+)/, '__REGEX_MEDIA_LINK__')

          links.each do |link|
            href = (/^ttp/).match(link) ? 'h'+link : link
            if (/\.(jpe?g|png|gif)$/).match(link)
              # 画像                                                                                                                                                                                
              contents.sub!(/__REGEX_MEDIA_LINK__/, '<a href="'+href+'" rel="lightbox" title="'+number.to_s+'" target="_tab"><img class="threadimage" src="'+href+'"></a>')
              contents_type = 2
            elsif (/h?ttp:\/\/www.youtube.com\/watch/).match(link)
              # 動画                                                                                                                                                                                
              href.gsub!(/&.+$/, '')
              iframe_src = href.sub(/\/watch(_popup)?\?v=/, '/embed/')
              contents.sub!(/__REGEX_MEDIA_LINK__/,
                        '<iframe class="youtube" title="YouTube video player" width="499" height="311" src="'+iframe_src+'" frameborder="0" allowfullscreen></iframe>')
              contents_type = 3
            else
              contents.sub!(/__REGEX_MEDIA_LINK__/, '<a href="'+href+'" target="_tab">'+link+'</a>')
              contents_type = 1 unless number == 1
            end
            
          end

          posting = PostingModel.new({
                                       :number => number,
                                       :hundle => hundle,
                                       :email => arr[1].strip,
                                       :posted => "#{posted_and_id[0]} #{posted_and_id[1]}",
                                       :id => posted_and_id[2] ? posted_and_id[2].strip : nil,
                                       :contents => contents,
                                       :parents => parents
                                     })

          articles << posting

          number += 1
        end
      end

      blog_summary = []
      articles.each do |article|
        if article.parents.size > 0
          next
        elsif article.children.size > 0
          blog_summary.concat(getChild(articles, article))
        elsif thread.owner == article.hundle
          blog_summary << article
        end
      end

      {:thread => thread, :postings => blog_summary}
    end # PostingSummary

  end
end

if __FILE__ == $0
  dat = "http://uni.2ch.net/newsplus/dat/1349525321.dat"
  res = Psycho::Util::PostingSummary(dat)
  res[:postings].each do |posting|
    puts "[#{posting.number}] #{posting.contents}"
  end
end
