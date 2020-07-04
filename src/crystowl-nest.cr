require "tourmaline"
require "tourmaline/extra/routed_menu"

require "yaml"

# TODO: Write documentation for `Crystowl`
# TODO: Checking feature
# TODO: Tainting feature preventing unnecessary updates
# TODO: Better exception handling and recovery
# TODO: Pass API key as command line argument

module Crystowl

  class GroceryList
    include YAML::Serializable

    @[YAML::Field(key: "content")]
    property content

    @content = {} of String => Int32

    def initialize
    end

    def dump
      str = "Liste:\n"
      @content.keys.sort.each do |index|
        value = @content[index]
        str += "#{index}: #{value}\n"
      end
      return str[0..4095]
    end

    def clear
      @content.clear
    end

    def add_item(item, amount)
      cut_item = item[0..99]

      if @content[cut_item]?
        @content[cut_item] += amount
      else
        @content[cut_item] = amount
      end
      @content[cut_item].clamp(0..999)
    end

    def remove_item(item, all = false, amount = 1)
      cut_item = item[0..99]

      if all
        @content.delete(cut_item)
      else
        @content[cut_item] -= amount
        if @content[cut_item] <= 0
          @content.delete(cut_item)
        end
      end
    end

    def save(filename)
      File.open(filename, "w") {|f| self.to_yaml(f)}
    end

  end

  class Whitelist
    include YAML::Serializable

    @[YAML::Field(key: "content")]
    property content

    @content = {} of Int64 => Bool

    def initialize
    end

  end

  class GroceryMenu < Tourmaline::RoutedMenu

    def initialize(@routes = {} of String => Page,
                   start_route = "/",
                   group = Tourmaline::Helpers.random_string(8))
                   
      @current_route = self.class.hash_route(start_route)
      @route_history = [@current_route]
      @event_handler = Tourmaline::CallbackQueryHandler.new(/(?:amount|route|final|refresh|custom):(\S+)/, group: group) do |ctx|

        user_id = ctx.query.from.id

        if match = ctx.match
          command = match[0].split(":")[0]
          
          if command == "amount"
            item = @routes[@current_route].content.split("\n")[-1]
            amount = match[1].to_i

            ChatBotInstance.add_item(item, amount)
            str = format_text_addition(item, amount)
            ctx.query.answer(str)
            ChatBotInstance.update_message(user_id)

            pseudo_handle(ctx)

          elsif command == "route"
            handle_button_click(ctx)

          elsif command == "final"
            ChatBotInstance.delete_message_and_menu(user_id)
            ChatBotInstance.disable_custom_add(user_id)
            ChatBotInstance.send_command_message(user_id)

          elsif command == "refresh"
            ChatBotInstance.update_message(user_id)

          elsif command == "custom"
            ctx.query.answer("Bitte Namen des Artikels eingeben")
            ChatBotInstance.enable_custom_add(user_id)

          else 
            puts "Invalid handle: #{command}"
            
          end
        end

        ChatBotInstance.save

      end

      @event_handler.unique = true
    end

    def format_text_addition(item, amount)
      return "#{amount} x #{item} hinzugefügt."
    end

    def pseudo_handle(ctx)
      route = ""

      if (message = ctx.query.message)
        if @route_history.size > 1
          route_history.pop
          route = route_history.pop
        else
          return ctx.query.answer("No page to go back to")
        end

        if page = @routes[route]?
          @current_route = route
          route_history << route
          message.edit_text(page.content,
                            reply_markup: page.buttons,
                            parse_mode: page.parse_mode,
                            disable_link_preview: !page.link_preview)
          ctx.query.answer
        else
          ctx.query.answer("Route not found")
        end
      end
    end

  end

  class CheckMenu < Tourmaline::RoutedMenu

    def initialize(@routes = {} of String => Page,
                   start_route = "/",
                   group = Tourmaline::Helpers.random_string(8))

      @current_route = self.class.hash_route(start_route)
      @route_history = [@current_route]
      @event_handler = Tourmaline::CallbackQueryHandler.new(/(?:remove_one|remove_all|route|final|refresh):(.+)/, group: group) do |ctx|

        user_id = ctx.query.from.id

        if match = ctx.match
          command = match[0].split(":")[0]
          
          if command == "remove_one"
            item = match[1]
            ChatBotInstance.remove_item(item, amount: 1)
            refresh(ctx)

            pseudo_handle(ctx)

          elsif command == "remove_all"
            item = match[1]
            ChatBotInstance.remove_item(item, all: true)
            refresh(ctx)

          elsif command == "route"
            handle_button_click(ctx)

          elsif command == "final"
            ChatBotInstance.delete_message_and_menu(user_id)
            ChatBotInstance.send_command_message(user_id)


          elsif command == "refresh"
            refresh(ctx)

          else 
            puts "Invalid handle: #{command}"
            
          end
        end

        ChatBotInstance.save

      end
      @event_handler.unique = true

    end

    def format_text_remove(item, amount)
      return "#{amount} x #{item} entfernt."
    end

    def refresh(ctx)
      current_page.buttons.inline_keyboard = Array(Array(Tourmaline::InlineKeyboardButton)).new

      ChatBotInstance.grocery_list.content.keys.sort.each do |index|
        row = Array(Tourmaline::InlineKeyboardButton).new
        current_page.buttons.inline_keyboard.push(row)

        value = ChatBotInstance.grocery_list.content[index]

        all_button = Tourmaline::InlineKeyboardButton.new(text: "#{index}", callback_data: "remove_all:#{index}")
        one_button = Tourmaline::InlineKeyboardButton.new(text: "#{value}", callback_data: "remove_one:#{index}")

        row.push(all_button)
        row.push(one_button)
      end

      row = Array(Tourmaline::InlineKeyboardButton).new
      current_page.buttons.inline_keyboard.push(row)

      refresh_button = Tourmaline::InlineKeyboardButton.new(text: "Update", callback_data: "refresh:true")
      final_button = Tourmaline::InlineKeyboardButton.new(text: "Fertig", callback_data: "final:true")

      row.push(refresh_button)
      row.push(final_button)

      ChatBotInstance.update_menu(current_page, ctx.query.from.id)
    end

    def pseudo_handle(ctx)
      route = ""

      if (message = ctx.query.message)
        if @route_history.size > 1
          route_history.pop
          route = route_history.pop
        else
          return ctx.query.answer("No page to go back to")
        end

        if page = @routes[route]?
          @current_route = route
          route_history << route
          message.edit_text(page.content,
                            reply_markup: page.buttons,
                            parse_mode: page.parse_mode,
                            disable_link_preview: !page.link_preview)
          ctx.query.answer
        else
          ctx.query.answer("Route not found")
        end
      end
    end

  end

  class Tourmaline::EventHandler
    property unique = false
  end

  class Tourmaline::Client
    def send_menu(chat, menu : Tourmaline::RoutedMenu, **kwargs)
      chat_id = chat.is_a?(Chat) ? chat.id : chat

      # We don't need any other handlers here
      event_handlers.reject! {|handler| handler.unique}

      add_event_handler(menu.event_handler)

      start_page = menu.current_page
      send_message(chat_id, start_page.content, **kwargs, reply_markup: start_page.buttons, parse_mode: start_page.parse_mode)
    end
  end

  class ChatBotInstance < Tourmaline::Client

    HELP_TEXT = "Kommandos:\n/start - Fügt Artikel hinzu\n/check - Entfernt Artikel\n/register - Sendet Registrierungsanfrage\n/help - Ruft diese Hilfe auf"
    NOT_WHITELIST_HELP_TEXT = "Kommandos:\n/register - Sendet Registrierungsanfrage"
    ANSWER_TEXT = "Anfrage für Registrierung ist erfolgt. Deine ID: "
    
    SAVE_FILE = "configs/list_"
    WHITELIST_FILE = "configs/whitelist_"
    FILE_ENDING = ".yml"

    @@grocery_list = GroceryList.new

    @@user_messages = {} of Int64 => Tourmaline::Message | Nil
    @@messages = {} of Int64 => Tourmaline::Message | Nil
    @@menus = {} of Int64 => Tourmaline::Message | Nil

    @@additions_enabled = {} of Int64 => Bool

    @@whitelist = Whitelist.new

    def self.grocery_list
      return @@grocery_list
    end

    def self.add_item(item, amount)
      @@grocery_list.add_item(item, amount)
    end

    def self.remove_item(item, all = false, amount = 1)
      @@grocery_list.remove_item(item, all: all, amount: amount)
    end

    def self.update_message(user_id)
      if @@messages[user_id]?
        begin
          @@messages[user_id].try &. edit_text(@@grocery_list.dump)
        rescue ex : Tourmaline::Error
          puts "ERROR: #{ex.message}"
        end
      end
    end

    def self.delete_message_and_menu(user_id)
      if @@messages[user_id]?
        @@messages[user_id].try &. delete
        @@messages.delete(user_id)
      end
      
      if @@menus[user_id]?
        @@menus[user_id].try &. delete
        @@menus.delete(user_id)
      end
    end

    def self.send_command_message(user_id)
      if @@user_messages[user_id]?
        @@user_messages[user_id].try &. respond(HELP_TEXT)
      end
    end

    def self.enable_custom_add(user_id)
      @@additions_enabled[user_id] = true
    end

    def self.disable_custom_add(user_id)
      @@additions_enabled[user_id] = false if user_id
    end

    def self.is_in_whitelist?(user_id)
      return @@whitelist.content[user_id]?
    end

    def self.save
      puts "Saving to #{SAVE_FILE + self.get_name + FILE_ENDING}"
      @@grocery_list.save(SAVE_FILE + self.get_name + FILE_ENDING)
    end

    def self.load_list
      if File.exists?(SAVE_FILE + self.get_name + FILE_ENDING)
        @@grocery_list = File.open(SAVE_FILE + self.get_name + FILE_ENDING) {|f| GroceryList.from_yaml(f)}
      else 
        @@grocery_list = GroceryList.new
      end
    end

    def self.load_whitelist
      if File.exists?(WHITELIST_FILE + self.get_name + FILE_ENDING)
        @@whitelist = File.open(WHITELIST_FILE + self.get_name + FILE_ENDING) {|f| Whitelist.from_yaml(f)}
      end
    end

    def self.get_name
      name = "DEFAULT"
      if ARGV[0]?
        name = ARGV[0]
      end
      return name
    end

    def self.load
      self.load_list
      self.load_whitelist
    end

    def self.update_menu(page, user_id)
      begin
        @@menus[user_id].try &. edit_text(page.content, reply_markup: page.buttons, parse_mode: page.parse_mode, disable_link_preview: !page.link_preview)
      rescue ex : Tourmaline::Error
        puts "ERROR: #{ex.message}"
      end
    end

    macro new_route(grocery_list, name, title, columns, items, 
      back = false, back_text = "", 
      generate_items = false, max_items = 3, 
      final = false, final_text = "", 
      refresh = false, refresh_text = "",
      custom = false, custom_text = "")

      route {{name}} do
        content {{title}}
        buttons(columns: {{columns}}) do

          {% for index, item in items %}
            route_button {{item}}, to: {{name}} + {{index}}
          {% end %}

          {% if custom %}
            callback_button {{custom_text}}, "custom:true"
          {% end %}

          {% if back %}
            back_button {{back_text}}
          {% end %}

          {% if refresh %}
            callback_button {{refresh_text}}, "refresh:true"
          {% end %}

          {% if final %}
            callback_button {{final_text}}, "final:true"
          {% end %}

        end
      end

      {% if generate_items %}
        {% for index, item in items %}
          route_items({{grocery_list}}, {{name}} + {{index}}, {{item}}, {{columns}}, {{max_items}}, back: true, back_text: {{back_text}})
        {% end %}
      {% end %}
    end

    macro route_items(grocery_list, name, title, columns, max_items, back = false, back_text = "")
      route {{name}} do
        content {{title}}
        buttons(columns: {{columns}}) do

          {% for i in (1..max_items) %}
            callback_button {{i.stringify}}, "amount:" + {{i.stringify}}
          {% end %}

          {% if back %}
            back_button {{back_text}}
          {% end %}

        end
      end
    end
    
    MENU = GroceryMenu.build do

      new_route(@@grocery_list, "/", "Bitte wähle eine Kategorie.", 3, {

        "food" => "Essen", 
        "drinks" => "Getränke",
        "spice" => "Gewürze",
        "household" => "Haushalt"

      }, custom: true, custom_text: "Andere", final: true, final_text: "Fertig", refresh: true, refresh_text: "Update")

      new_route(@@grocery_list, "/food", "Essen", 3, {

        "/noodles" => "Nudeln", 
        "/rice" => "Reis", 
        "/toast" => "Toast",

        "/butter" => "Butter",
        "/sausage" => "Wurst",
        "/cheese" => "Käse",

        "/meat" => "Fleisch",
        "/salad" => "Salat",
        "/fruit" => "Obst",

        "/onions" => "Zwiebeln",
        "/bell" => "Paprika",
        "/carrot" => "Möhren"

      }, back: true, back_text: "Zurück", generate_items: true, max_items: 3)

      new_route(@@grocery_list, "/drinks", "Getränke", 3, {

        "/water" => "Wasser", 
        "/juice" => "Saft", 
        "/milk" => "Milch",

        "/coke" => "Cola",
        "/tea" => "Tee",
        "/icetea" => "Eistee"

      }, back: true, back_text: "Zurück", generate_items: true, max_items: 3)

      new_route(@@grocery_list, "/spice", "Gewürze", 3, {

        "/salt" => "Salz",
        "/pepper" => "Pfeffer",
        "/herbs" => "Kräuter",

        "/ketchup" => "Ketchup",
        "/sauces" => "Saucen",
        "/chili" => "Chili"

      }, back: true, back_text: "Zurück", generate_items: true, max_items: 3)

      new_route(@@grocery_list, "/household", "Haushalt", 3, {

        "/toiletpaper" => "Klopapier",
        "/tissue" => "Küchentuch",
        "/soap" => "Seife",

        "/sponge" => "Schwämme",
        "/dishwashertab" => "Spültabs",
        "/washing" => "Waschmittel"

      }, back: true, back_text: "Zurück", generate_items: true, max_items: 3)

    end

    @[Command("start")]
    def start_command(ctx)
      if user_id = ctx.message.from.try &. id
        if ChatBotInstance.is_in_whitelist?(user_id)
          @@user_messages[user_id] = ctx.message
          @@messages[user_id] = ctx.message.respond("Lädt Liste...")
          ChatBotInstance.update_message(user_id)
          @@menus[user_id] = ctx.message.respond_with_menu(MENU)
        end
      end
    end

    @[Command("check")]
    def check_command(ctx)
      if user_id = ctx.message.from.try &. id
        if ChatBotInstance.is_in_whitelist?(user_id)
          @@user_messages[user_id] = ctx.message
          @@messages[user_id] = nil

          checklist = CheckMenu.build do
            route "/" do 
              content "Einkaufsliste"

              buttons(columns: 2) do
                @@grocery_list.content.keys.sort.each do |index|
                  value = @@grocery_list.content[index]
                  callback_button "#{index}", "remove_all:#{index}"
                  callback_button "#{value}", "remove_one:#{index}"
                end
                callback_button "Update", "refresh:true"
                callback_button "Fertig", "final:true"
              end

            end
          end

          @@menus[user_id] = ctx.message.respond_with_menu(checklist)
        end
      end
    end

    @[Command("help")]
    def help_command(ctx)
      if user_id = ctx.message.from.try &. id
        if ChatBotInstance.is_in_whitelist?(user_id)
          ctx.message.respond(HELP_TEXT)
        else
          ctx.message.respond(NOT_WHITELIST_HELP_TEXT)
        end
      end
    end

    @[Command("register")]
    def register_command(ctx)
      if user = ctx.message.from
        puts "New user wants to register:"
        if username = user.try &. username
          puts "User: " + username
        end
        puts "Name: " + user.try &. full_name
        puts "ID: " + user.try &. id.to_s
        ctx.message.respond(ANSWER_TEXT + user.try &. id.to_s)
      end
    end

    @[Command("reset")]
    def reset_command(ctx)
      user_id = ctx.message.from.try &. id
      if ChatBotInstance.is_in_whitelist?(user_id)
        @@grocery_list.clear
        ctx.message.respond("Liste gelöscht.")
      end
    end

    @[Command("reload")]
    def reload_command(ctx)
      user_id = ctx.message.from.try &. id
      if ChatBotInstance.is_in_whitelist?(user_id)
        ChatBotInstance.load
        ctx.message.respond("Liste aus Cache geladen.")
      end
    end

    @[Command("full_reset")]
    def full_reset_command(ctx)
      user_id = ctx.message.from.try &. id
      if ChatBotInstance.is_in_whitelist?(user_id)
        @@grocery_list.clear
        ChatBotInstance.save
        ctx.message.respond("Liste und Cache gelöscht.")
      end
    end

    @[Hears(/^\s*([\w\-äöüÄÖÜßéèÈÉáàÀÁêÊ][\w\-äöüÄÖÜßéèÈÉáàÀÁêÊ\s]*)$/)]
    def on_addition(ctx)
      user_id = ctx.message.from.try &. id
      if ChatBotInstance.is_in_whitelist?(user_id)
        if @@additions_enabled[user_id]
          if text = ctx.message.text
            number = 1
            article = ""
            split_text = text.strip.split
            
            if split_text[-1].to_i?
              number = split_text[-1].to_i
              article = split_text[0..-2].join(" ")
            else
              article = split_text.join(" ")
            end

            @@grocery_list.add_item(article, number)

            ChatBotInstance.disable_custom_add(user_id)
            ChatBotInstance.update_message(user_id)
            ChatBotInstance.save

            ctx.message.delete
          end
        end
      end
    end

  end
end

bot = Crystowl::ChatBotInstance.new(ENV["CRYSTOWL_API_KEY"])
Crystowl::ChatBotInstance.load
bot.poll