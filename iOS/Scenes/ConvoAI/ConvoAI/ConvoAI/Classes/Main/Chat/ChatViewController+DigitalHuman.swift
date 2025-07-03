//
//  ChatViewController+DigitalHuman.swift
//  ConvoAI
//
//  Created by qinhui on 2025/7/3.
//

import Foundation
import Common

extension ChatViewController {
    internal func openDigitalHuman() {
        digitalHumanContainerView.isHidden = false
        animateContentView.isHidden = true
    }
    
    internal func closeDigitalHuman() {
        digitalHumanContainerView.isHidden = true
        animateContentView.isHidden = false
    }
}
