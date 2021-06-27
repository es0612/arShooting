import SwiftUI

enum GameState {

    // ゲームメニューを表示しています
    case menu

    // 現実世界の平面を探しています
    case placingContent

    // ステージ1を表示しています
    case stage1

    // ステージ2を表示しています
    case stage2

    // ゲーム終了
    case endGame

    // 現実世界の平面を探しています(対戦モード)
     case multiPlayPlacingContent

     // 対戦画面を表示します
     case multiPlayMode

     // 勝利画面を表示します
     case multiPlayWin

     // 敗北画面を表示します
     case multiPlayLose

    // 現実世界の平面を探しています(CPU対戦モード)
        case multiPlayCPUPlacingContent

        // CPU対戦
        case multiPlayCPUMode

    // 長さ測定モード
       case rulerMode

       // 長さ測定モード終了
       case rulerModeEnd
}

final class GameInfo: ObservableObject {
    @Published var gameState: GameState = .menu
    @Published var selfLife: Int = 10
    @Published var enemyLife: Int = 10
    @Published var distance: Float = 0.0
}
