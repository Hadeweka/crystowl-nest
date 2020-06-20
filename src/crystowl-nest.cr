require "crystowl"

require "tourmaline/extra/routed_menu"

# TODO: Write documentation for `Crystowl`
module Crystowl

  class GroceryList
    @content = {} of String => Int32

    def dump
      str = "Liste:\n"
      @content.each do |index, value|
        str += "#{index}: #{value}\n"
      end
      return str[0..4095]
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

  end

  class GroceryMenu < Tourmaline::RoutedMenu

    def initialize(@routes = {} of String => Page,
                   start_route = "/",
                   group = Tourmaline::Helpers.random_string(8))
      @current_route = self.class.hash_route(start_route)
      @route_history = [@current_route]
      @event_handler = Tourmaline::CallbackQueryHandler.new(/(?:amount|route|final|refresh|custom):(\S+)/, group: group) do |ctx|

        if match = ctx.match
          command = match[0].split(":")[0]
          
          if command == "amount"
            item = @routes[@current_route].content.split("\n")[-1]
            amount = match[1].to_i

            Greeter.add_item(item, amount)
            str = format_text_addition(item, amount)
            ctx.query.answer(str)
            Greeter.update_message

            pseudo_handle(ctx)

          elsif command == "route"
            handle_button_click(ctx)

          elsif command == "final"
            Greeter.delete_message_and_menu
            Greeter.disable_custom_add
            Greeter.send_command_message

          elsif command == "refresh"
            Greeter.update_message

          elsif command == "custom"
            ctx.query.answer("Bitte Namen des Artikels eingeben")
            Greeter.enable_custom_add
            
          end
        end

      end
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

  class Greeter < Tourmaline::Client

    HELP_TEXT = "Kommandos:\n/start - Fügt Artikel hinzu\n/check - Entfernt Artikel\n/help - Ruft diese Hilfe auf"
    ANSWER_TEXT = "Anfrage für Registrierung ist erfolgt."

    @@grocery_list = GroceryList.new
    
    # TODO: Make all of these user-specific!

    @@user_message : Tourmaline::Message | Nil
    @@message : Tourmaline::Message | Nil
    @@menu : Tourmaline::Message | Nil

    @@accepts_addition = false

    @@user_messages = {} of Int64 => Tourmaline::Message | Nil
    @@messages = {} of Int64 => Tourmaline::Message | Nil
    @@menus = {} of Int64 => Tourmaline::Message | Nil

    @additions_enabled = {} of Int64 => Bool

    def self.add_item(item, amount)
      @@grocery_list.add_item(item, amount)
    end

    def self.update_message
      begin
        @@message.try &. edit_text(@@grocery_list.dump)
      rescue ex : Tourmaline::Error
        puts "ERROR: #{ex.message}"
      end
    end

    def self.delete_message_and_menu
      @@message.try &. delete
      @@menu.try &. delete
    end

    def self.send_command_message
      @@user_message.try &. respond(HELP_TEXT)
    end

    def self.enable_custom_add
      @@accepts_addition = true
    end

    def self.disable_custom_add
      @@accepts_addition = false
    end

    def self.is_custom_add
      return @@accepts_addition
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
      @@user_message = ctx.message
      @@message = ctx.message.respond("Lädt Liste...")
      Greeter.update_message
      @@menu = ctx.message.respond_with_menu(MENU)
    end

    @[Command("help")]
    def help_command(ctx)
      ctx.message.respond(HELP_TEXT)
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
        ctx.message.respond(ANSWER_TEXT)
      end
    end

    @[Hears(/^\s*([\w\-äöüÄÖÜßéèÈÉáàÀÁêÊ][\w\-äöüÄÖÜßÈÉáàÀÁêÊ\s]*)$/)]
    def on_addition(ctx)
      if @@accepts_addition
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

          Greeter.disable_custom_add
          Greeter.update_message
          ctx.message.delete
        end
      end
    end

  end
end

bot = Crystowl::Greeter.new(ENV["CRYSTOWL_API_KEY"])
bot.poll