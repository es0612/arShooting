//
//  ContentView.swift
//  ArShootingApp
//
//  Created by Ema Shinya on 2021/01/14.
//

import SwiftUI
import RealityKit

struct ArTitlerView : View {
    @EnvironmentObject var gameInfo: GameInfo

    var body: some View {

        let arView = ARViewContainer(gameInfo: gameInfo).edgesIgnoringSafeArea(.all)

        let view = ZStack {
            // ARViewを表示
            arView
            ArButtonView()
            ArResultView()
            
        }

        return view
    }
}

struct ARViewContainer: UIViewRepresentable {
    var gameInfo: GameInfo

    func makeUIView(context: Context) -> UIView {

        return ARShootingView(frame: .zero, gameInfo: gameInfo)
    }

    func updateUIView(_ uiView: UIView, context: Context) {}

}

#if DEBUG
struct ContentView_Previews : PreviewProvider {
    static var previews: some View {
        ArTitlerView()
    }
}
#endif
