import MultipeerConnectivity

extension ARShootingView: MCSessionDelegate {

    // セッション状態(接続/接続中/切断)が変更されたら呼ばれます
    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {

        // 接続
        if state == .connected {
            peerConnected(peerID)
        }
        // 切断
        else if state == .notConnected {
            peerDisconnected(peerID)
        }
    }

    // データを受信したら呼ばれます
    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        recvData(data, from: peerID)
    }

    // 接続中のピアから受信したバイトストリーム
    func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String,
                 fromPeer peerID: MCPeerID) {}

    // Resourceの受信開始
    func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String,
                 fromPeer peerID: MCPeerID, with progress: Progress) {}

    // Resourceの受信完了
    func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String,
                 fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {}

}

extension ARShootingView: MCNearbyServiceAdvertiserDelegate {

    // 他のiPhone/iPadから接続を要求されたら呼ばれます
    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID,
                    withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) {

        // 無条件で招待を受け入れます
        invitationHandler(true, multiSession)
    }
}

extension ARShootingView: MCNearbyServiceBrowserDelegate {

    // 接続できるiPhone/iPadを見つけたら呼ばれます
    func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String: String]?) {

        // 現在の接続台数を判定します
        let accepted = peerDiscovered(peerID)
        if accepted {

            // 接続要求を送信します
            browser.invitePeer(peerID, to: multiSession, withContext: nil, timeout: 10)
        }
    }

    // 他のiPhone/iPadが接続要求を止めたら呼ばれます
    func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {}
}
