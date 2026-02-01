defmodule Mix.Tasks.Project.Gen.HotwireNative do
  @shortdoc "Generates Hotwire Native server-side setup"
  @moduledoc """
  Sets up Turbo, Stimulus, bridge components, native app detection,
  path configuration endpoints, and conditional styling for
  Hotwire Native mobile apps.
  """
  use Igniter.Mix.Task

  alias Mix.Tasks.Project.Helpers

  @impl Igniter.Mix.Task
  def igniter(igniter) do
    igniter
    |> create_stimulus_controllers()
    |> create_bridge_button_controller()
    |> update_app_js()
    |> update_app_css()
    |> create_hotwire_native_plug()
    |> create_hotwire_controller()
    |> update_router()
    |> update_root_layout()
    |> update_session_max_age()
    |> create_docs()
    |> add_npm_packages()
    |> Igniter.add_task("assets.setup")
  end

  defp add_npm_packages(igniter) do
    packages = ["@hotwired/turbo", "@hotwired/stimulus", "@hotwired/hotwire-native-bridge"]
    versions = Helpers.fetch_npm_versions_parallel(packages)

    new_deps = %{
      "@hotwired/turbo" => versions["@hotwired/turbo"] || "^8.0.0",
      "@hotwired/stimulus" => versions["@hotwired/stimulus"] || "^3.2.0",
      "@hotwired/hotwire-native-bridge" => versions["@hotwired/hotwire-native-bridge"] || "^1.1.0"
    }

    if Igniter.exists?(igniter, "assets/package.json") do
      Igniter.update_file(igniter, "assets/package.json", fn source ->
        content = Rewrite.Source.get(source, :content)

        updated =
          content
          |> Jason.decode!()
          |> Map.update("dependencies", new_deps, &Map.merge(&1, new_deps))
          |> Jason.encode!(pretty: true)

        Rewrite.Source.update(source, :content, updated <> "\n")
      end)
    else
      contents = Jason.encode!(%{"dependencies" => new_deps}, pretty: true)
      Igniter.create_new_file(igniter, "assets/package.json", contents <> "\n")
    end
  end

  defp create_stimulus_controllers(igniter) do
    index_content = """
    import { Application } from "@hotwired/stimulus"

    const application = Application.start()

    // Import and register controllers here.
    import HelloController from "./hello_controller"
    application.register("hello", HelloController)

    // Bridge components (native app ↔ web communication).
    import BridgeButtonController from "./bridge/button_controller"
    application.register("bridge--button", BridgeButtonController)

    export { application }
    """

    hello_content = """
    import { Controller } from "@hotwired/stimulus"

    // Connects to data-controller="hello"
    export default class extends Controller {
      connect() {
        console.log("Hello, Stimulus!", this.element)
      }
    }
    """

    igniter
    |> Igniter.create_new_file("assets/js/controllers/index.js", String.trim(index_content) <> "\n")
    |> Igniter.create_new_file("assets/js/controllers/hello_controller.js", String.trim(hello_content) <> "\n")
  end

  defp create_bridge_button_controller(igniter) do
    content = """
    import { BridgeComponent } from "@hotwired/hotwire-native-bridge"

    // Connects to data-controller="bridge--button"
    //
    // On native apps, sends the button title to the native side which renders
    // a native navigation bar button. When tapped, the callback clicks the
    // original HTML element to submit forms or follow links.
    //
    // On web, this controller is a no-op — BridgeComponent.connect() only
    // fires when the "button" component is registered in the native app's
    // user agent.
    export default class extends BridgeComponent {
      static component = "button"

      connect() {
        super.connect()

        const title = this.bridgeElement.title
        this.send("connect", { title }, () => {
          this.bridgeElement.click()
        })
      }
    }
    """

    Igniter.create_new_file(
      igniter,
      "assets/js/controllers/bridge/button_controller.js",
      String.trim(content) <> "\n"
    )
  end

  defp update_app_js(igniter) do
    turbo_lines = """

    // Turbo Drive for SPA-like page navigation (Hotwire Native hooks into this).
    import "@hotwired/turbo"

    // Stimulus controllers (registered in controllers/index.js).
    import "./controllers"
    """

    Helpers.update_file_content(igniter, "assets/js/app.js", fn content ->
      if String.contains?(content, "@hotwired/turbo") do
        content
      else
        String.replace(
          content,
          ~s|import "phoenix_html"\n|,
          ~s|import "phoenix_html"\n| <> turbo_lines
        )
      end
    end)
  end

  defp update_app_css(igniter) do
    hotwire_css = """
    /* Hotwire Native variants -- show/hide content based on native app context.
       Usage: hotwire-native:hidden  not-hotwire-native:hidden */
    @custom-variant hotwire-native (html[data-hotwire-native] &);
    @custom-variant not-hotwire-native (html:not([data-hotwire-native]) &);
    """

    Helpers.update_file_content(igniter, "assets/css/app.css", fn content ->
      if String.contains?(content, "hotwire-native") do
        content
      else
        String.trim_trailing(content) <> "\n\n" <> hotwire_css
      end
    end)
  end

  defp create_hotwire_native_plug(igniter) do
    app_web = Helpers.app_web_module(igniter)
    app_web_path = Macro.underscore(app_web)

    content = ~s'''
    defmodule #{app_web}.Plugs.HotwireNative do
      @moduledoc """
      Detects Hotwire Native mobile apps via the User-Agent header.

      Hotwire Native iOS/Android apps automatically append "Hotwire Native"
      to the user agent on every request. This plug sets
      `conn.assigns.hotwire_native?` accordingly.
      """

      import Plug.Conn

      def init(opts), do: opts

      def call(conn, _opts) do
        assign(conn, :hotwire_native?, hotwire_native_app?(conn))
      end

      defp hotwire_native_app?(conn) do
        case get_req_header(conn, "user-agent") do
          [user_agent | _] -> String.contains?(user_agent, "Hotwire Native")
          [] -> false
        end
      end
    end
    '''

    Igniter.create_new_file(igniter, "lib/#{app_web_path}/plugs/hotwire_native.ex", content)
  end

  defp create_hotwire_controller(igniter) do
    app_web = Helpers.app_web_module(igniter)
    app_web_path = Macro.underscore(app_web)

    content = ~s'''
    defmodule #{app_web}.HotwireController do
      use #{app_web}, :controller

      @moduledoc """
      Serves path configuration JSON for Hotwire Native iOS and Android apps.

      Path configuration tells the native apps how to present different URL
      patterns -- e.g. forms as modals, specific routes as native screens.
      The JSON is fetched once on app launch and can be updated server-side
      without releasing a new app version.
      """

      def ios_v1(conn, _params) do
        json(conn, %{
          settings: %{},
          rules: [
            %{
              patterns: ["/new$", "/edit$"],
              properties: %{
                context: "modal"
              }
            }
          ]
        })
      end

      def android_v1(conn, _params) do
        json(conn, %{
          settings: %{},
          rules: [
            %{
              patterns: [".*"],
              properties: %{
                uri: "hotwire://fragment/web",
                pull_to_refresh_enabled: true
              }
            },
            %{
              patterns: ["/new$", "/edit$"],
              properties: %{
                context: "modal",
                pull_to_refresh_enabled: false
              }
            }
          ]
        })
      end
    end
    '''

    Igniter.create_new_file(igniter, "lib/#{app_web_path}/controllers/hotwire_controller.ex", content)
  end

  defp update_router(igniter) do
    app_web = Helpers.app_web_module(igniter)
    {igniter, router} = Igniter.Libs.Phoenix.select_router(igniter)

    igniter
    |> add_hotwire_plug(router, app_web)
    |> add_configuration_routes(router, app_web)
  end

  defp add_hotwire_plug(igniter, router, app_web) do
    plug_code = "plug #{app_web}.Plugs.HotwireNative"

    Igniter.Project.Module.find_and_update_module!(igniter, router, fn zipper ->
      case Sourceror.Zipper.search_pattern(zipper, "plug :put_secure_browser_headers") do
        nil -> {:ok, Igniter.Code.Common.add_code(zipper, plug_code)}
        found -> {:ok, Igniter.Code.Common.add_code(found, plug_code)}
      end
    end)
  end

  defp add_configuration_routes(igniter, router, app_web) do
    Igniter.Libs.Phoenix.add_scope(
      igniter,
      "/configurations",
      """
      pipe_through :api

      get "/ios_v1", #{app_web}.HotwireController, :ios_v1
      get "/android_v1", #{app_web}.HotwireController, :android_v1
      """,
      router: router
    )
  end

  defp update_root_layout(igniter) do
    app_web_path = Helpers.app_web_module(igniter) |> Macro.underscore()
    path = "lib/#{app_web_path}/components/layouts/root.html.heex"

    Helpers.update_file_content(igniter, path, fn content ->
      if String.contains?(content, "data-hotwire-native") do
        content
      else
        String.replace(
          content,
          "<html lang=\"en\">",
          "<html lang=\"en\" data-hotwire-native={@hotwire_native? || nil}>"
        )
      end
    end)
  end

  defp update_session_max_age(igniter) do
    app_web_path = Helpers.app_web_module(igniter) |> Macro.underscore()
    path = "lib/#{app_web_path}/endpoint.ex"

    Helpers.update_file_content(igniter, path, fn content ->
      if String.contains?(content, "max_age") do
        content
      else
        String.replace(
          content,
          ~s|same_site: "Lax"|,
          ~s|same_site: "Lax",\n    max_age: 60 * 60 * 24 * 60|
        )
      end
    end)
  end

  defp create_docs(igniter) do
    app_module = Helpers.app_module(igniter)
    app_web = Helpers.app_web_module(igniter)
    app_web_path = Macro.underscore(app_web)

    replace = fn content ->
      content
      |> String.replace("{{APP_WEB_PATH}}", app_web_path)
      |> String.replace("{{APP_WEB}}", app_web)
      |> String.replace("{{APP_MODULE}}", app_module)
    end

    igniter
    |> Igniter.create_new_file("docs/hotwire-native-ios.md", replace.(ios_doc_content()))
    |> Igniter.create_new_file("docs/hotwire-native-reference.md", replace.(reference_doc_content()))
  end

  defp ios_doc_content do
    ~S'''
    # Running the iOS Simulator with Hotwire Native

    This guide walks through creating a Hotwire Native iOS app that renders
    content from our Phoenix server in an embedded web view.

    **Prerequisites:** Xcode 16+ installed from the Mac App Store.

    ---

    ## Step 1: Start the Phoenix server

    ```bash
    mix phx.server
    ```

    The server runs at `http://localhost:4000`. The iOS simulator shares the
    host machine's network, so `localhost` works directly (unlike the Android
    emulator which needs `10.0.2.2`).

    ---

    ## Step 2: Create a new Xcode project

    1. Open Xcode → **Create New Project…**
    2. Select **iOS** at the top, then **App** from the Application section. Click **Next**.
    3. Fill in:
       - **Product Name:** `{{APP_MODULE}}` (no spaces)
       - **Interface:** Storyboard
       - **Language:** Swift
       - **Testing System:** None
       - **Organization Identifier:** reverse domain, e.g. `com.yourcompany`
    4. Click **Next**, choose a save location (e.g. an `ios/` directory next to the
       Phoenix project), and click **Create**.
    5. Make sure an iPhone simulator is selected as the run destination at the
       top of Xcode (not a physical device).

    ---

    ## Step 3: Add the Hotwire Native Swift package

    1. In Xcode, click **File → Add Package Dependencies…**
    2. Paste this URL in the search box at the upper right:
       ```
       https://github.com/hotwired/hotwire-native-ios
       ```
    3. Set **Dependency Rule** to **Up to Next Minor Version**, enter `1.2.0`.
    4. Click **Add Package**.
    5. On the next screen, make sure your app target is selected under
       **Add to Target**, then click **Add Package** again.

    ---

    ## Step 4: Configure SceneDelegate

    Open `SceneDelegate.swift` and replace its entire contents with:

    ```swift
    import HotwireNative
    import UIKit

    let baseURL = URL(string: "http://localhost:4000")!

    class SceneDelegate: UIResponder, UIWindowSceneDelegate {
        var window: UIWindow?

        private let navigator = Navigator(configuration: .init(
            name: "main",
            startLocation: baseURL.appending(path: "/")
        ))

        func scene(
            _ scene: UIScene,
            willConnectTo session: UISceneSession,
            options connectionOptions: UIScene.ConnectionOptions
        ) {
            window?.rootViewController = navigator.rootViewController
            navigator.start()
        }
    }
    ```

    Key differences from the book's Rails setup:
    - `baseURL` points to port **4000** (Phoenix default, not Rails' 3000).
    - `startLocation` is `"/"` — change this to whatever route you want on launch.

    ---

    ## Step 5: Configure AppDelegate with path configuration

    Open `AppDelegate.swift` and replace its contents with:

    ```swift
    import HotwireNative
    import UIKit

    @main
    class AppDelegate: UIResponder, UIApplicationDelegate {
        func application(
            _ application: UIApplication,
            didFinishLaunchingWithOptions launchOptions:
                [UIApplication.LaunchOptionsKey: Any]?
        ) -> Bool {
            Hotwire.loadPathConfiguration(from: [
                .server(baseURL.appending(path: "configurations/ios_v1.json"))
            ])

            return true
        }
    }
    ```

    This tells the app to fetch path configuration from our Phoenix endpoint
    at `/configurations/ios_v1`. The JSON rules (e.g. presenting `/new` and
    `/edit` routes as modals) are applied automatically.

    ---

    ## Step 6: Delete the unused ViewController

    Xcode generates a `ViewController.swift` file by default. We don't need it —
    right-click it in the Project Navigator and select **Delete → Move to Trash**.

    ---

    ## Step 7: Build and run

    Press **⌘R** (or **Product → Run**) to build and run the app in the simulator.

    The simulator should launch and display the Phoenix app's homepage inside
    the native navigation chrome. You can tap links to navigate between pages —
    Hotwire Native handles the navigation stack automatically.

    ---

    ## Troubleshooting

    ### Blank white screen
    - Verify `mix phx.server` is running and `http://localhost:4000` loads in Safari.
    - Check the Xcode console for network errors.

    ### "App Transport Security" error
    If you see ATS errors, add this to your `Info.plist` (only for local development):

    ```xml
    <key>NSAppTransportSecurity</key>
    <dict>
        <key>NSAllowsLocalNetworking</key>
        <true/>
    </dict>
    ```

    Xcode 16+ typically allows localhost by default, so this may not be needed.

    ### Testing native detection
    Once the app loads, requests will include "Hotwire Native" in the user agent.
    Any content styled with `hotwire-native:hidden` or `not-hotwire-native:hidden`
    will respond accordingly.

    ---

    ## Next steps

    - **Add tabs:** See Chapter 4 of the book — create a `Tabs.swift` model and
      migrate from `Navigator` to `HotwireTabBarController`.
    - **Bridge components:** Add `data-controller="bridge--button"` to form submit
      buttons in Phoenix templates. Then create the native `ButtonComponent` in
      Swift (Chapter 7).
    - **Native screens:** Use `NavigatorDelegate` and path configuration's
      `view_controller` property to route specific URLs to SwiftUI views (Chapter 5).
    '''
  end

  defp reference_doc_content do
    ~S'''
    # Hotwire Native Reference

    This document provides the full context an AI agent needs to work on Hotwire
    Native features in this Phoenix application. It is adapted from the book
    "Hotwire Native for Rails Developers" by Joe Masilotti (Pragmatic Bookshelf, 2025).

    ---

    ## What Hotwire Native Is

    Hotwire Native is a framework for building hybrid mobile apps on iOS and Android.
    It renders HTML from your server inside a native web view, wrapped in a native
    navigation shell. You build screens once in HTML and deploy them across web,
    iOS, and Android simultaneously. Deploy to your server and you're done — no
    repackaging apps or resubmitting to app stores.

    The native apps are thin clients. Most logic stays on the server. When a web
    experience isn't sufficient, individual screens or components can be upgraded
    to native Swift (iOS) or Kotlin (Android) on a case-by-case basis.

    ---

    ## Architecture

    ```
    ┌─────────────────────────────────────────┐
    │  Native App (iOS / Android)             │
    │  ┌───────────────────────────────────┐  │
    │  │  Native Navigation (tab bar,      │  │
    │  │  back buttons, title bar)         │  │
    │  ├───────────────────────────────────┤  │
    │  │  Web View                         │  │
    │  │  ┌─────────────────────────────┐  │  │
    │  │  │  HTML from Phoenix server   │  │  │
    │  │  │  (Turbo Drive navigation)   │  │  │
    │  │  └─────────────────────────────┘  │  │
    │  └───────────────────────────────────┘  │
    │  ┌───────────────────────────────────┐  │
    │  │  Bridge Components (optional)     │  │
    │  │  Stimulus ↔ Native communication  │  │
    │  └───────────────────────────────────┘  │
    │  ┌───────────────────────────────────┐  │
    │  │  Native Screens (optional)        │  │
    │  │  SwiftUI / Jetpack Compose        │  │
    │  └───────────────────────────────────┘  │
    └─────────────────────────────────────────┘
             │
             │  HTTP (Turbo Drive visits)
             ▼
    ┌─────────────────────────────────────────┐
    │  Phoenix Server                         │
    │  - HTML responses (controllers/LiveView)│
    │  - Path configuration JSON endpoints    │
    │  - Native detection via User-Agent      │
    │  - Conditional CSS / Tailwind variants  │
    │  - JSON APIs for native screens         │
    └─────────────────────────────────────────┘
    ```

    ### How Navigation Works

    1. User taps a link in the web view.
    2. Turbo Drive intercepts the click and performs a "visit" to the URL.
    3. Hotwire Native catches the Turbo visit and checks path configuration rules.
    4. Based on the rules, the native app either:
       - Pushes a new web view screen (default)
       - Presents a modal (if `context: "modal"`)
       - Routes to a native SwiftUI/Compose screen (if `view_controller` / `uri` is set)
    5. The server responds with HTML, which is rendered in the web view.
    6. The native title bar reads the `<title>` tag and displays it automatically.

    ### Snapshot Cache

    Hotwire Native screenshots every page. When navigating back, the snapshot loads
    instantly from memory while the fresh page loads in the background. The cache
    is busted after any non-GET request (form submissions, etc.), ensuring the
    back stack shows fresh data.

    ---

    ## This Project's Setup

    ### Server Stack
    - **Phoenix 1.8** with LiveView, Bandit web server
    - **Bun** for JS bundling (not esbuild/webpack)
    - **Tailwind CSS v4** with custom variants
    - **Turbo Drive** for SPA-like page navigation
    - **Stimulus** for JS behavior controllers
    - **@hotwired/hotwire-native-bridge** for bridge components

    ### Key Files

    | File | Purpose |
    |------|---------|
    | `assets/js/app.js` | Entry point — imports Turbo, Stimulus, LiveView |
    | `assets/js/controllers/index.js` | Stimulus controller registration |
    | `assets/js/controllers/bridge/` | Bridge component Stimulus controllers |
    | `assets/css/app.css` | Tailwind config with `hotwire-native:` variants |
    | `lib/{{APP_WEB_PATH}}/plugs/hotwire_native.ex` | Detects native apps via User-Agent |
    | `lib/{{APP_WEB_PATH}}/controllers/hotwire_controller.ex` | Path configuration JSON endpoints |
    | `lib/{{APP_WEB_PATH}}/components/layouts/root.html.heex` | Root layout with `data-hotwire-native` attr |
    | `lib/{{APP_WEB_PATH}}/router.ex` | Routes including `/configurations/*` |
    | `lib/{{APP_WEB_PATH}}/endpoint.ex` | Session config with 60-day max_age |
    | `ios/{{APP_MODULE}}/` | Xcode project for iOS app |

    ### Native App Detection

    The plug `{{APP_WEB}}.Plugs.HotwireNative` checks the `User-Agent` header for
    the string `"Hotwire Native"`. Both iOS and Android Hotwire Native apps
    append this automatically to every request.

    - **In controllers:** `conn.assigns.hotwire_native?`
    - **In templates:** `@hotwire_native?`
    - **In root layout:** sets `data-hotwire-native` attribute on `<html>` tag

    ### Conditional Styling

    Two Tailwind v4 custom variants are defined in `assets/css/app.css`:

    ```css
    @custom-variant hotwire-native (html[data-hotwire-native] &);
    @custom-variant not-hotwire-native (html:not([data-hotwire-native]) &);
    ```

    Usage in templates:
    ```heex
    <%!-- Hidden in native apps, visible on web --%>
    <nav class="hotwire-native:hidden">Web navigation</nav>

    <%!-- Visible only in native apps --%>
    <button class="hidden hotwire-native:block">Sign out</button>
    ```

    The `hidden hotwire-native:block` pattern combines Tailwind's `hidden` (display:none
    everywhere) with `hotwire-native:block` (display:block in native apps only).

    ### Dynamic Titles

    Hotwire Native reads the HTML `<title>` tag and displays it in the native
    navigation bar automatically. Phoenix's `<.live_title>` in the root layout
    already handles this. Set per-page titles with `assign(conn, :page_title, "My Page")`
    in controllers or `assign(socket, :page_title, "My Page")` in LiveView.

    ---

    ## Path Configuration

    Path configuration is a JSON file hosted on the server that tells native apps
    how to present different URL patterns. It is fetched on app launch and can be
    updated without app store releases.

    ### Endpoints

    - iOS: `GET /configurations/ios_v1` → `HotwireController.ios_v1`
    - Android: `GET /configurations/android_v1` → `HotwireController.android_v1`

    These go through the `:api` pipeline (JSON, no HTML layout).

    ### JSON Structure

    ```json
    {
      "settings": {},
      "rules": [
        {
          "patterns": ["/new$", "/edit$"],
          "properties": {
            "context": "modal"
          }
        }
      ]
    }
    ```

    **`settings`** — app-wide key-value pairs. Not used by the framework directly;
    available for custom app logic.

    **`rules`** — array of pattern/property pairs, applied top-to-bottom. All
    matching rules are merged, so later rules can override earlier ones.

    ### Rule Properties

    | Property | Values | Effect |
    |----------|--------|--------|
    | `context` | `"default"`, `"modal"` | How the screen is presented |
    | `view_controller` (iOS) | arbitrary string, e.g. `"map"` | Routes to a native UIViewController |
    | `uri` (Android) | e.g. `"hotwire://fragment/web"` | Routes to a registered Fragment |
    | `pull_to_refresh_enabled` (Android) | `true`/`false` | Enable pull-to-refresh |
    | `title` (Android) | string | Override the native title |

    ### Pattern Matching

    Patterns are regular expressions matched against the URL path:
    - `"/new$"` — paths ending in `/new`
    - `"/edit$"` — paths ending in `/edit`
    - `"/hikes/[0-9]+/map"` — hike map pages
    - `".*"` — wildcard, matches everything (Android requires this as a base rule)

    ### Android vs iOS Differences

    Android requires a wildcard `".*"` rule with `uri: "hotwire://fragment/web"` as the
    first rule. iOS does not need this. Android also requires `pull_to_refresh_enabled`
    to be explicitly set and should be disabled on modals to prevent conflicts
    with modal dismissal gestures.

    ---

    ## Bridge Components

    Bridge components enable communication between a Stimulus controller on the web
    and a native component in the iOS/Android app. They let you upgrade individual
    UI elements to native without converting entire screens.

    ### Three Building Blocks

    1. **HTML markup** — a `data-controller` attribute on an element (e.g. a submit button)
    2. **Stimulus controller** — extends `BridgeComponent`, sends/receives messages
    3. **Native component** — Swift class (iOS) or Kotlin class (Android) that
       renders native UI and responds to messages

    ### How Messages Flow

    ```
    HTML element (data-controller="bridge--button")
        │
        ▼
    Stimulus BridgeComponent subclass
        │  this.send("connect", { title: "Save" }, callback)
        ▼
    Native BridgeComponent subclass
        │  onReceive(message:) → renders native button
        │  reply(to:) → triggers the callback
        ▼
    Stimulus callback
        │  this.bridgeElement.click() → clicks the original HTML element
        ▼
    Form submits / link navigates as normal
    ```

    ### Stimulus Controller Pattern

    ```javascript
    import { BridgeComponent } from "@hotwired/hotwire-native-bridge"

    export default class extends BridgeComponent {
      static component = "button"  // must match native component name

      connect() {
        super.connect()
        const title = this.bridgeElement.title
        this.send("connect", { title }, () => {
          this.bridgeElement.click()
        })
      }
    }
    ```

    Key points:
    - `static component` must match the native side's component name.
    - `this.bridgeElement` wraps the HTML element with the `data-controller` attribute.
    - `this.send(event, data, callback)` sends a message to native.
    - The callback fires when the native side calls `reply(to:)`.
    - `connect()` only fires when the native app has registered this component in
      its user agent. On regular web browsers, bridge components are inert.

    ### Controller Naming Convention

    Bridge controllers are namespaced under `bridge/` and referenced with double
    dashes in HTML: `data-controller="bridge--button"` maps to
    `assets/js/controllers/bridge/button_controller.js`.

    ### Registering Controllers

    Controllers are manually registered in `assets/js/controllers/index.js`:

    ```javascript
    import BridgeButtonController from "./bridge/button_controller"
    application.register("bridge--button", BridgeButtonController)
    ```

    ### Native Side (iOS — Swift)

    ```swift
    class ButtonComponent: BridgeComponent {
        override class var name: String { "button" }

        override func onReceive(message: Message) {
            // Create native UI and call reply(to:) when tapped
        }
    }
    ```

    Register in `AppDelegate.swift`:
    ```swift
    Hotwire.registerBridgeComponents([ButtonComponent.self])
    ```

    ### Native Side (Android — Kotlin)

    Register in the Application subclass:
    ```kotlin
    Hotwire.registerBridgeComponents(BridgeComponentFactory("button", ::ButtonComponent))
    ```

    ---

    ## When to Go Native vs Keep Web

    ### Go Native
    - **Home screen** — fast launch, highest fidelity, can cache for offline
    - **Maps** — pinch/zoom/pan gestures work properly
    - **Native API integration** — HealthKit, camera beyond basic file input, sensors
    - **Tab bars** — use `HotwireTabBarController` (iOS) / `HotwireBottomNavigationController` (Android)

    ### Keep as Web
    - **Settings/preferences** — change frequently, cheap to update
    - **CRUD screens** — not unique to the app experience
    - **Dynamic content feeds** — heterogeneous items require per-type native views
    - **Checkout flows** — change frequently (coupons, fields, payment methods)

    ### The Middle Ground: Bridge Components
    When you want a little native fidelity without committing to an entire native
    screen. Examples: native submit buttons in the nav bar, native action sheets,
    native share dialogs.

    ---

    ## Turbo + LiveView Coexistence

    This project uses both Turbo Drive and Phoenix LiveView:

    - **Turbo Drive** handles full-page navigation for controller-rendered pages.
      This is what Hotwire Native hooks into for its visit lifecycle.
    - **LiveView** handles real-time updates via WebSocket for interactive pages.

    They don't conflict because LiveView manages its own navigation. If a page
    is rendered by a LiveView, Turbo won't interfere with it. For pages where
    both might try to handle navigation, add `data-turbo="false"` to the container.

    ---

    ## iOS App Structure

    The iOS Xcode project lives in `ios/{{APP_MODULE}}/`.

    | File | Role |
    |------|------|
    | `AppDelegate.swift` | App launch — loads path configuration, registers bridge components |
    | `SceneDelegate.swift` | Creates `Navigator` pointed at `http://localhost:4000`, sets root view controller |
    | `Info.plist` | App metadata, permissions |

    ### Key iOS Classes (from Hotwire Native)

    - **`Navigator`** — manages the navigation stack and web view. Each tab gets its own Navigator.
    - **`HotwireTabBarController`** — native tab bar, each tab backed by a Navigator.
    - **`BridgeComponent`** — base class for native bridge components.
    - **`NavigatorDelegate`** — implement `handle(proposal:from:)` to route URLs to custom view controllers.
    - **`ProposalResult`** — return `.accept` (web view), `.acceptCustom(vc)` (native screen), or `.reject`.

    ### Adding Native Screens (iOS)

    1. Create a SwiftUI view.
    2. Wrap it in a `UIHostingController` subclass.
    3. Add a path configuration rule with `view_controller: "your-name"`.
    4. Implement `NavigatorDelegate.handle(proposal:from:)` in `SceneDelegate`.
    5. Match `proposal.viewController == "your-name"` and return `.acceptCustom(YourController(url:))`.
    6. Expose a JSON endpoint on the server for structured data the native screen needs.

    ### Adding Tabs (iOS)

    1. Create a `Tabs.swift` model with `HotwireTab` instances (title, SF Symbol image, URL).
    2. Replace `Navigator` in `SceneDelegate` with `HotwireTabBarController`.
    3. Call `tabBarController.load(HotwireTab.all)` in `scene(_:willConnectTo:options:)`.

    ---

    ## Android App Structure

    The Android project would live in `android/` (not yet created in this project).

    ### Key Android Classes (from Hotwire Native)

    - **`HotwireActivity`** — base activity, requires `navigatorConfigurations()`.
    - **`NavigatorConfiguration`** — name, start location, and fragment host ID.
    - **`HotwireBottomNavigationController`** — native bottom tab bar.
    - **`HotwireFragment` / `HotwireWebFragment`** — fragments for native/web screens.
    - **`@HotwireDestinationDeepLink`** — annotation to register a fragment's URI for path config routing.

    ### Android-Specific Notes

    - The Android emulator uses `10.0.2.2` instead of `localhost` to reach the host machine.
    - Fragments registered with `Hotwire.registerFragmentDestinations()` in the Application subclass.
    - `AndroidManifest.xml` needs `android.permission.INTERNET` and `android:usesCleartextTraffic="true"` for local dev.
    - SDK 35+ requires `enableEdgeToEdge()` and `applyDefaultImeWindowInsets()` in the activity.

    ---

    ## Common Server-Side Patterns

    ### Hiding web navigation in native apps
    ```heex
    <nav class="hotwire-native:hidden">
      <a href="/">Home</a>
      <a href="/settings">Settings</a>
    </nav>
    ```

    ### Adding native-only sign out button
    ```heex
    <.link href={~p"/session"} method="delete"
      class="hidden hotwire-native:block"
      data-turbo-method="delete"
      data-turbo-confirm="Sign out?">
      Sign out
    </.link>
    ```

    ### Bridge component on a form submit button
    ```heex
    <button type="submit"
      data-controller="bridge--button"
      title="Save">
      Save
    </button>
    ```

    The `title` attribute is read by the bridge controller and sent to the native
    side, which renders a native button with that label in the navigation bar.

    ### Conditional rendering in controllers
    ```elixir
    def show(conn, %{"id" => id}) do
      item = Items.get!(id)

      if conn.assigns.hotwire_native? do
        # Render a simplified view for native apps
        render(conn, :show_native, item: item)
      else
        render(conn, :show, item: item)
      end
    end
    ```

    ### JSON endpoint for native screens
    ```elixir
    def show(conn, %{"id" => id}) do
      item = Items.get!(id)

      case get_format(conn) do
        "json" -> json(conn, %{name: item.name, lat: item.latitude, lng: item.longitude})
        "html" -> render(conn, :show, item: item)
      end
    end
    ```

    Native iOS/Android screens fetch `/{resource}.json` to get structured data
    for rendering in SwiftUI or Jetpack Compose.
    '''
  end
end
