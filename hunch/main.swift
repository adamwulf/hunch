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

        guard let url = URL(string: "https://api.notion.com/v1/databases") else { fatalError() }
        let session = URLSession(configuration: .ephemeral)
        var req = URLRequest(url: url)
        req.addValue("Bearer " + token, forHTTPHeaderField: "Authorization")


        let task = session.dataTask(with: req) { data, response, error in
            guard let data = data else { return }
            print(String(data: data, encoding: .utf8)!)
            exit()
        }

        task.resume()
        CFRunLoopRun()
    }

    func exit() {
        CFRunLoopStop(CFRunLoopGetMain())
    }
}

Hunch.main()
