//
//  main.swift
//  hunch
//
//  Created by Adam Wulf on 5/19/21.
//

import Foundation
import ArgumentParser

print("Hello, World!")

struct Hunch: ParsableCommand {
    @Argument() var token: String

    func run() {
        print(token)

        NotionAPI.shared.token = token
        NotionAPI.shared.fetchDatabases { result in
            switch result {
            case .success(let dbs):
                print(dbs)
            case .failure(let error):
                print(error)
            }

            exit()
        }
        CFRunLoopRun()
    }

    func exit() {
        CFRunLoopStop(CFRunLoopGetMain())
    }
}

Hunch.main()
