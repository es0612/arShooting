//
//  ArButtonView.swift
//  ArShootingApp
//
//  Created by Ema Shinya on 2021/02/04.
//

import SwiftUI

struct ArButtonView: View {
    @EnvironmentObject var gameInfo: GameInfo

    var body: some View {
        // タイトルとボタンを表示
        VStack(spacing: 200) {
            if gameInfo.gameState == .menu {
                // タイトル
                Text("ARShooting")
                    .font(Font.custom("HelveticaNeue-Bold", size: 60.0))
            }
            VStack(spacing: 50) {
                // ボタン
                Button(action: {
                    self.gameInfo.gameState = .placingContent
                }) {
                    if gameInfo.gameState == .menu {
                        Text("Game Start")
                    }

                }
                Button(action: {
                    self.gameInfo.gameState = .multiPlayPlacingContent
                }) {

                    if gameInfo.gameState == .menu {
                        Text("MultiPlay Start")
                            .font(.body)
                    }
                }

                Button(action: {
                    self.gameInfo.gameState = .multiPlayCPUPlacingContent
                }) {

                    if gameInfo.gameState == .menu {
                        Text("MultiPlay(CPU) Start")
                            .font(.body)
                    }
                }

                Button(action: {
                                    self.gameInfo.gameState = .rulerMode
                }) {

                    if gameInfo.gameState == .menu {
                        Text("Ruler mode")
                            .font(.body)
                    }
                }
            }
        }
    }
}

struct ArButtonView_Previews: PreviewProvider {
    static var previews: some View {
        ArButtonView()
    }
}
