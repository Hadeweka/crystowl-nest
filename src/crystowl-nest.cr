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
      return str
    end

    def add_item(item, amount)
      if @content[item]?
        @content[item] += amount
      else
        @content[item] = amount
      end
    end

  end

  class GroceryMenu < Tourmaline::RoutedMenu

    def initialize(@routes = {} of String => Page,
                   start_route = "/",
                   group = Tourmaline::Helpers.random_string(8))
      @current_route = self.class.hash_route(start_route)
      @route_history = [@current_route]
      @event_handler = Tourmaline::CallbackQueryHandler.new(/(?:amount|route):(\S+)/, group: group) do |ctx|

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

    @@grocery_list = GroceryList.new
    @@message : Tourmaline::Message | Nil

    def self.add_item(item, amount)
      @@grocery_list.add_item(item, amount)
    end

    def self.update_message
      @@message.try &. edit_text(@@grocery_list.dump)
    end

    macro new_route(grocery_list, name, title, columns, items, back = false, back_text = "", generate_items = false, max_items = 3)
      route {{name}} do
        content {{title}}
        buttons(columns: {{columns}}) do
          {% for index, item in items %}
            route_button {{item}}, to: {{name}} + {{index}}
          {% end %}

          {% if back %}
            back_button {{back_text}}
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
        "household" => "Haushalt",

        "custom" => "Andere"

      })

      new_route(@@grocery_list, "/food", "Essen", 3, {

        "/noodles" => "Nudeln", 
        "/rice" => "Reis", 
        "/toast" => "Toast",

        "/butter" => "Butter",
        "/cuts" => "Aufschnitt",
        "/ketchup" => "Ketchup"

      }, back: true, back_text: "Zurück", generate_items: true, max_items: 3)

      new_route(@@grocery_list, "/drinks", "Getränke", 3, {

        "/water" => "Wasser", 
        "/juice" => "Saft", 
        "/milk" => "Milch",

        "/coke" => "Cola",
        "/tea" => "Tee",
        "/icetea" => "Eistee"

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
      @@message = ctx.message.respond("Liste:")
      ctx.message.respond_with_menu(MENU)
    end

  end
end

bot = Crystowl::Greeter.new(ENV["CRYSTOWL_API_KEY"])
bot.poll