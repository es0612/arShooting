//
//  ArResultView.swift
//  ArShootingApp
//
//  Created by Ema Shinya on 2021/02/04.
//

import SwiftUI

struct ArResultView: View {
    @EnvironmentObject var gameInfo: GameInfo
    
    var body: some View {
        // ステージ表示中
        if  gameInfo.gameState == .stage1 ||
                gameInfo.gameState == .stage2 ||
                gameInfo.gameState == .multiPlayMode ||
                gameInfo.gameState == .multiPlayCPUMode {

            // ライフが残っている状態
            if gameInfo.selfLife > 0 {

                VStack {

                    HStack {

                        Spacer()
                        if gameInfo.gameState == .multiPlayMode ||
                            gameInfo.gameState == .multiPlayCPUMode {

                            // 敵ライフ表示
                            Text("EnemyLife: " + String(gameInfo.enemyLife))
                                .foregroundColor(.red)
                                .font(.system(size: 30))
                                .padding([.trailing, .top], 15)
                        }
                        else {
                            // タイトル画面へ戻るボタン
                            Button(action: {

                                self.gameInfo.gameState = .menu
                            }) {

                                Text("Menu")
                                    .padding([.trailing, .top], 15)
                            }
                        }
                    }

                    Spacer()

                    HStack {

                        // ライフ表示
                        Text("Life: " + String(gameInfo.selfLife))
                            .foregroundColor(.white)
                            .font(.system(size: 30))
                            .padding([.leading, .bottom], 15)

                        Spacer()
                    }
                }
            }
            else {

                VStack(spacing: 200) {

                    // ゲームオーバー
                    Text("Game Over")
                        .foregroundColor(.white)
                        .font(.system(size: 60))

                    // 全回復して、続けてプレイ
                    Button(action: {

                        self.gameInfo.selfLife = 10
                    }) {

                        Text("Continue")
                    }
                }
            }
        }

        else if gameInfo.gameState == .multiPlayWin {
            VStack(spacing: 200) {

                // 勝利
                Text("You Win")
                    .foregroundColor(.white)
                    .font(.system(size: 60))

                Button(action: {

                    self.gameInfo.gameState = .menu
                }) {

                    Text("Menu")
                }
            }
        }
        else if gameInfo.gameState == .multiPlayLose {
            VStack(spacing: 200) {

                // 敗北
                Text("You Lose")
                    .foregroundColor(.white)
                    .font(.system(size: 60))

                Button(action: {

                    self.gameInfo.gameState = .menu
                }) {

                    Text("Menu")
                }
            }
        }
        else if  gameInfo.gameState == .endGame {

            VStack(spacing: 200) {

                // ゲーム終了
                Text("Congratulation")
                    .foregroundColor(.white)
                    .font(.system(size: 60))

                // タイトル画面へ戻る
                Button(action: {

                    self.gameInfo.gameState = .menu
                }) {

                    Text("Menu")
                }
            }
        }

        else if gameInfo.gameState == .rulerMode {

            VStack {

                HStack {

                    // 距離表示
                    Text("Distance: " + String(format: "%.2f", gameInfo.distance)  + "m")
                        .foregroundColor(.white)
                        .font(.system(size: 30))
                        .padding([.leading, .bottom], 15)

                    Spacer()

                    // タイトル画面へ戻るボタン
                    Button(action: {

                        self.gameInfo.gameState = .rulerModeEnd
                    }) {

                        Text("Menu")
                            .padding([.trailing, .top], 15)
                    }
                }

                Spacer()
            }
        }
    }
}

struct ArResultView_Previews: PreviewProvider {
    static var previews: some View {
        ArResultView()
    }
}
