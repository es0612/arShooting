import Foundation
import ARKit
import RealityKit
import Combine
import MultipeerConnectivity

//MARK:- MultiPlay

class ARSimulator: NSObject {

    static let multiServiceType = "multiAR"

    let multiPeerID = MCPeerID(displayName: "ARSimulator")
    var multiSession: MCSession!
    var multiAdvertiser: MCNearbyServiceAdvertiser!
    var multiBrowser: MCNearbyServiceBrowser!

    // マルチビア接続
    func setupMultiPlay() {

        // データの送受信を行うクラス
        multiSession = MCSession(peer: multiPeerID, securityIdentity: nil, encryptionPreference: .required)
        multiSession.delegate = self

        // 近くのpeerに自身を告知します
        multiAdvertiser = MCNearbyServiceAdvertiser(peer: multiPeerID, discoveryInfo: nil, serviceType: ARShootingView.multiServiceType)
        multiAdvertiser.delegate = self
        multiAdvertiser.startAdvertisingPeer()

        // 近くのpeerを招待します
        multiBrowser = MCNearbyServiceBrowser(peer: multiPeerID, serviceType: ARShootingView.multiServiceType)
        multiBrowser.delegate = self
        multiBrowser.startBrowsingForPeers()
    }

    // 対戦モード終了
    func stopMultiPlay() {

        // P2P通信停止
        multiAdvertiser.stopAdvertisingPeer()
        multiBrowser.stopBrowsingForPeers()
        multiSession.disconnect()
    }

    // データ受信
    func recvData(_ data: Data, from peer: MCPeerID) {

        // コラボレーションデータの場合
        if let collaborationData = try? NSKeyedUnarchiver.unarchivedObject(ofClass: ARSession.CollaborationData.self, from: data)
        {
            print("collaborationData:", collaborationData)
        }
        // ダメージ判定の場合
        else if let commandString = String(data: data, encoding: .utf8), commandString.hasPrefix(SendType.damage) {

            print(commandString)
        }
    }

    // 接続判定
    func peerDiscovered(_ peer :MCPeerID) -> Bool {

        // 1台だけ接続を許可
        if multiSession.connectedPeers.count >= 2 {
            return false
        }
        else {
            return true
        }
    }

    // 接続
    func peerConnected(_ peer :MCPeerID) {}

    // 切断
    func peerDisconnected(_ peer :MCPeerID) {}
}


