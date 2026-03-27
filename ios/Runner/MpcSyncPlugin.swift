import Flutter
import UIKit
import MultipeerConnectivity

class MpcSyncPlugin: NSObject, FlutterPlugin {
    private var channel: FlutterMethodChannel?
    private var session: MCSession?
    private var browser: MCNearbyServiceBrowser?
    private var advertiser: MCNearbyServiceAdvertiser?
    private var myPeerID: MCPeerID?
    private var connectedPeer: MCPeerID?

    private let serviceType = "airdrop-service"

    static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(
            name: "dev.lifevalue.healthwallet/mpc_sync",
            binaryMessenger: registrar.messenger()
        )
        let instance = MpcSyncPlugin()
        instance.channel = channel
        registrar.addMethodCallDelegate(instance, channel: channel)
    }

    func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "startAdvertising":
            startAdvertising(result: result)
        case "startBrowsing":
            startBrowsing(result: result)
        case "sendData":
            guard let args = call.arguments as? [String: Any],
                  let data = args["data"] as? FlutterStandardTypedData else {
                result(FlutterError(code: "INVALID_ARGS", message: "data required", details: nil))
                return
            }
            sendData(data.data, result: result)
        case "disconnect":
            disconnect(result: result)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    private func initialize() {
        guard myPeerID == nil else { return }

        let displayName = UIDevice.current.name
        myPeerID = MCPeerID(displayName: displayName)

        guard let peerID = myPeerID else { return }

        session = MCSession(peer: peerID, securityIdentity: nil, encryptionPreference: .required)
        session?.delegate = self
    }

    private func startAdvertising(result: @escaping FlutterResult) {
        initialize()

        guard let peerID = myPeerID else {
            result(FlutterError(code: "NOT_INIT", message: "Failed to initialize", details: nil))
            return
        }

        advertiser?.stopAdvertisingPeer()
        advertiser = MCNearbyServiceAdvertiser(
            peer: peerID,
            discoveryInfo: ["app": "healthwallet", "device": "iOS", "name": peerID.displayName],
            serviceType: serviceType
        )
        advertiser?.delegate = self
        advertiser?.startAdvertisingPeer()
        NSLog("[MpcSync] Advertising started as '%@'", peerID.displayName)
        result(nil)
    }

    private func startBrowsing(result: @escaping FlutterResult) {
        initialize()

        guard let peerID = myPeerID else {
            result(FlutterError(code: "NOT_INIT", message: "Failed to initialize", details: nil))
            return
        }

        browser?.stopBrowsingForPeers()
        browser = MCNearbyServiceBrowser(peer: peerID, serviceType: serviceType)
        browser?.delegate = self
        browser?.startBrowsingForPeers()
        NSLog("[MpcSync] Browsing started")
        result(nil)
    }

    private func sendData(_ data: Data, result: @escaping FlutterResult) {
        guard let session = session, let peer = connectedPeer else {
            result(FlutterError(code: "NOT_CONNECTED", message: "No connected peer", details: nil))
            return
        }

        do {
            try session.send(data, toPeers: [peer], with: .reliable)
            result(nil)
        } catch {
            result(FlutterError(code: "SEND_FAILED", message: error.localizedDescription, details: nil))
        }
    }

    private func disconnect(result: @escaping FlutterResult) {
        browser?.stopBrowsingForPeers()
        browser = nil
        advertiser?.stopAdvertisingPeer()
        advertiser = nil
        session?.disconnect()
        connectedPeer = nil
        result(nil)
    }
}

extension MpcSyncPlugin: MCSessionDelegate {
    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        DispatchQueue.main.async { [weak self] in
            switch state {
            case .connected:
                NSLog("[MpcSync] Connected to: %@", peerID.displayName)
                self?.connectedPeer = peerID
                self?.browser?.stopBrowsingForPeers()
                self?.channel?.invokeMethod("onPeerConnected", arguments: [
                    "deviceName": peerID.displayName
                ])
            case .notConnected:
                if self?.connectedPeer == peerID {
                    NSLog("[MpcSync] Disconnected from: %@", peerID.displayName)
                    self?.connectedPeer = nil
                    self?.channel?.invokeMethod("onPeerDisconnected", arguments: nil)
                }
            case .connecting:
                NSLog("[MpcSync] Connecting to: %@", peerID.displayName)
            @unknown default:
                break
            }
        }
    }

    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        DispatchQueue.main.async { [weak self] in
            self?.channel?.invokeMethod("onDataReceived", arguments: [
                "data": FlutterStandardTypedData(bytes: data)
            ])
        }
    }

    func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {}
    func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {}
    func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {}
}

extension MpcSyncPlugin: MCNearbyServiceAdvertiserDelegate {
    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID, withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        NSLog("[MpcSync] Auto-accepting invitation from: %@", peerID.displayName)
        invitationHandler(true, session)
    }

    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didNotStartAdvertisingPeer error: Error) {
        NSLog("[MpcSync] Advertise failed: %@", error.localizedDescription)
    }
}

extension MpcSyncPlugin: MCNearbyServiceBrowserDelegate {
    func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String: String]?) {
        NSLog("[MpcSync] Found peer: %@ info: %@", peerID.displayName, info?.description ?? "nil")

        guard connectedPeer == nil else { return }

        NSLog("[MpcSync] Inviting peer: %@", peerID.displayName)
        browser.invitePeer(peerID, to: session!, withContext: nil, timeout: 10)
    }

    func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        NSLog("[MpcSync] Lost peer: %@", peerID.displayName)
    }

    func browser(_ browser: MCNearbyServiceBrowser, didNotStartBrowsingForPeers error: Error) {
        NSLog("[MpcSync] Browse failed: %@", error.localizedDescription)
    }
}
