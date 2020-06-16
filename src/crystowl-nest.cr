require "crystowl"

require "tourmaline/extra/routed_menu"

# TODO: Write documentation for `Crystowl`
module Crystowl

  class GroceryList
    @content = {} of String => Int32

  end

  class GroceryMenu < Tourmaline::RoutedMenu

    @grocery_list = GroceryList.new

    def initialize(@routes = {} of String => Page,
                   start_route = "/",
                   group = Tourmaline::Helpers.random_string(8))
      @current_route = self.class.hash_route(start_route)
      @route_history = [@current_route]
      @event_handler = Tourmaline::CallbackQueryHandler.new(/(?:amount|route):(\S+)/, group: group) do |ctx|
        puts ctx.match

        if match = ctx.match
          command = match[0].split(":")[0]
          puts command
          
          if command == "amount"
            puts match[1].to_i
            pseudo_handle(ctx)

          elsif command == "route"
            puts "Handling..."
            handle_button_click(ctx)

          end
        end
      end
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
    
    MY_MENU = GroceryMenu.build do
      route "/" do
        content "Bitte wähle eine Kategorie."
        buttons(columns: 3) do
          route_button "Essen", to: "/food"
          route_button "Getränke", to: "/drinks"
          route_button "Andere", to: "/custom"
        end
      end

      route "/food" do
        content "Essen"
        buttons(columns: 3) do
          route_button "Nudeln", to: "/food/noodles"
          route_button "Reis", to: "/food/rice"
          route_button "Toast", to: "/food/toast"
        end
      end

      route "/drinks" do
        content "Getränke"
        buttons(columns: 3) do
          route_button "Wasser", to: "/drinks/water"
          route_button "Apfelsaft", to: "/drinks/applejuice"
          route_button "Milch", to: "/drinks/milk"
        end
      end

      route "/food/noodles" do
        content "Nudeln"
        buttons(columns: 3) do
          callback_button "1", "amount:1"
          callback_button "2", "amount:2"
          callback_button "3", "amount:3"
          back_button "Zurück"
        end
      end

    end

    @[Command("start")]
    def start_command(ctx)
      ctx.message.respond_with_menu(MY_MENU)
    end

  end
end

bot = Crystowl::Greeter.new(ENV["CRYSTOWL_API_KEY"])
bot.poll