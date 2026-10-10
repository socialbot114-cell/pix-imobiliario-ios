import XCTest

final class BankFlowUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-ui-testing"]
        app.launch()
    }

    func testCreateGameAndRegisterTransfer() throws {
        XCTAssertTrue(app.staticTexts["A mesa está pronta."].waitForExistence(timeout: 8))
        createGameWithPlayers()

        XCTAssertTrue(app.staticTexts["Noite de Jogo"].waitForExistence(timeout: 6))
        XCTAssertTrue(app.staticTexts["M$ 2.450,00"].waitForExistence(timeout: 4))
        openLeaderboard()
        let anaStanding = app.descendants(matching: .any)["leaderboard-row-1"]
        let brunoStanding = app.descendants(matching: .any)["leaderboard-row-2"]
        XCTAssertTrue(anaStanding.label.contains("1º"))
        XCTAssertTrue(brunoStanding.label.contains("1º"))
        XCTAssertTrue(anaStanding.label.contains("M$ 2.450,00"))
        app.buttons["Fechar"].tap()

        tapHomeAction("PIX")
        XCTAssertTrue(app.navigationBars["PIX Imobiliário"].waitForExistence(timeout: 4))
        let amountField = app.textFields["transfer-amount-field"]
        XCTAssertTrue(amountField.waitForExistence(timeout: 3))
        amountField.tap()
        amountField.typeText("50")
        app.buttons["Revisar"].tap()
        XCTAssertTrue(app.staticTexts["Revise seu PIX"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["edit-transfer"].exists)
        app.buttons["Confirmar"].tap()

        XCTAssertTrue(app.staticTexts["transfer-receipt-title"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["transfer-receipt-amount"].label, "M$ 50,00")
        XCTAssertTrue(app.descendants(matching: .any)["transfer-receipt-local-state"].label.contains("Nenhum PIX oficial"))
        let closeReceipt = app.buttons["transfer-receipt-close"]
        if !closeReceipt.isHittable { app.swipeUp() }
        closeReceipt.tap()
        XCTAssertTrue(app.staticTexts["M$ 2.400,00"].waitForExistence(timeout: 5))
        openLeaderboard()
        XCTAssertTrue(app.descendants(matching: .any)["leaderboard-row-1"].label.contains("2º"))
        XCTAssertTrue(app.descendants(matching: .any)["leaderboard-row-2"].label.contains("1º"))
        XCTAssertTrue(app.descendants(matching: .any)["leaderboard-row-2"].label.contains("M$ 2.500,00"))
        app.buttons["Fechar"].tap()
        app.tabBars.buttons["Extrato"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["transaction-row-3"].waitForExistence(timeout: 5))
        app.descendants(matching: .any)["transaction-row-3"].tap()
        XCTAssertTrue(app.navigationBars["Comprovante"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.descendants(matching: .any)["transaction-receipt-reference"].label.contains("MOV-3"))
    }

    func testPlayerSetupValidatesDuplicateNamesAndSupportsAddingPlayers() throws {
        app.buttons["create-game-button"].tap()
        XCTAssertTrue(app.buttons["continue-to-players"].waitForExistence(timeout: 4))
        app.buttons["continue-to-players"].tap()

        let createButton = app.buttons["confirm-create-game"]
        XCTAssertTrue(createButton.waitForExistence(timeout: 4))
        XCTAssertFalse(createButton.isEnabled)

        let addPlayerButton = app.buttons["add-player-button"]
        if !addPlayerButton.isHittable { app.swipeUp() }
        addPlayerButton.tap()
        XCTAssertTrue(app.textFields["player-name-3"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["player-count"].label.contains("3 de 6"))
        let removePlayerButton = app.buttons["remove-player-3"]
        if !removePlayerButton.isHittable { app.swipeUp() }
        removePlayerButton.tap()
        XCTAssertFalse(app.textFields["player-name-3"].exists)
        XCTAssertTrue(app.staticTexts["player-count"].label.contains("2 de 6"))

        let firstName = app.textFields["player-name-1"]
        let secondName = app.textFields["player-name-2"]
        firstName.tap()
        firstName.typeText("Ana")
        secondName.tap()
        secondName.typeText("ana")
        XCTAssertFalse(createButton.isEnabled)
        XCTAssertTrue(app.descendants(matching: .any)["setup-validation-message"].exists)
    }

    func testDemoAccessMockIsOptionalAndDoesNotRequestCredentials() throws {
        app.buttons["demo-access-preview"].tap()
        XCTAssertTrue(app.navigationBars["Acesso"].waitForExistence(timeout: 4))
        XCTAssertTrue(app.staticTexts["demo-access-title"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["demo-no-credentials"].exists)
        XCTAssertEqual(app.textFields.count, 0)

        let continueDemo = app.buttons["demo-access-continue"]
        if !continueDemo.isHittable { app.swipeUp() }
        continueDemo.tap()
        XCTAssertTrue(app.buttons["continue-to-players"].waitForExistence(timeout: 5))
    }

    func testTransferProcessingStateClearlyIndicatesLocalOperation() throws {
        app.terminate()
        app = XCUIApplication()
        app.launchArguments = ["-ui-testing", "-screenshot-mode", "-capture-transfer-processing"]
        app.launch()

        let processingState = app.descendants(matching: .any)["transfer-processing-state"]
        XCTAssertTrue(processingState.waitForExistence(timeout: 8))
        XCTAssertTrue(processingState.label.contains("Processando PIX local"))
        XCTAssertFalse(app.buttons["confirm-transfer-button"].isEnabled)
    }

    func testPremiumBoardTabIsReachable() throws {
        app.terminate()
        app = XCUIApplication()
        app.launchArguments = ["-ui-testing", "-screenshot-mode", "-capture-tab-board"]
        app.launch()
        XCTAssertTrue(app.buttons["roll-board-dice"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["Sua jogada"].exists)
        let boardScene = app.descendants(matching: .any)["board-scene"]
        XCTAssertTrue(boardScene.waitForExistence(timeout: 5))
        XCTAssertTrue((boardScene.value as? String)?.contains("Ana: casa 1 de 20") == true)
    }

    func testPropertyPurchaseIsVisibleInStatement() throws {
        app.terminate()
        app = XCUIApplication()
        app.launchArguments = ["-ui-testing", "-screenshot-mode", "-capture-tab-properties"]
        app.launch()
        XCTAssertTrue(app.staticTexts["Rua do Ipê"].waitForExistence(timeout: 8))
        app.buttons["buy-property-1"].tap()
        app.tabBars.buttons["Extrato"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["transaction-row-5"].waitForExistence(timeout: 6))
    }

    func testChargeWaitsForPayerThenRecordsPayment() throws {
        createGameWithPlayers()
        XCTAssertTrue(app.staticTexts["Noite de Jogo"].waitForExistence(timeout: 6))
        tapHomeAction("Cobrar")
        XCTAssertTrue(app.navigationBars["Nova cobrança"].waitForExistence(timeout: 4))
        let amountField = app.textFields["charge-amount-field"]
        XCTAssertTrue(amountField.waitForExistence(timeout: 3))
        amountField.tap()
        amountField.typeText("40")
        app.buttons["create-charge-button"].tap()

        XCTAssertTrue(app.staticTexts["Cobranças aguardando"].waitForExistence(timeout: 5))
        let payButton = app.buttons["Pagar"]
        if !payButton.isHittable { app.swipeUp() }
        payButton.tap()
        XCTAssertTrue(app.staticTexts["M$ 2.490,00"].waitForExistence(timeout: 5))
    }

    func testBankCanCreditStartingSquareIncome() throws {
        createGameWithPlayers()
        XCTAssertTrue(app.staticTexts["Noite de Jogo"].waitForExistence(timeout: 6))
        tapHomeAction("Banco")
        XCTAssertTrue(app.navigationBars["Movimentação do banco"].waitForExistence(timeout: 4))
        let amountField = app.textFields["bank-operation-amount"]
        amountField.tap()
        amountField.typeText("200")
        app.textFields["bank-operation-description"].tap()
        app.textFields["bank-operation-description"].typeText("Passou pela casa inicial")
        app.buttons["confirm-bank-operation"].tap()
        XCTAssertTrue(app.staticTexts["M$ 2.650,00"].waitForExistence(timeout: 5))
    }

    func testLargeDynamicTypeKeepsBalanceAndPrimaryActionsReachable() throws {
        app.terminate()
        app = XCUIApplication()
        app.launchArguments = [
            "-ui-testing",
            "-screenshot-mode",
            "-UIPreferredContentSizeCategoryName",
            "UICTContentSizeCategoryAccessibilityXXXL"
        ]
        app.launch()

        XCTAssertTrue(app.staticTexts["Noite de Jogo"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.staticTexts["balance-value"].exists)
        let pixButton = app.buttons["home-action-PIX"]
        for _ in 0..<5 {
            if pixButton.exists && pixButton.isHittable { break }
            app.swipeUp()
        }
        XCTAssertTrue(pixButton.waitForExistence(timeout: 5))
        XCTAssertTrue(pixButton.isHittable)
        XCTAssertTrue(app.tabBars.buttons["Extrato"].exists)
    }

    func testLocalGameDataCanBeDeletedFromTheGameMenu() throws {
        createGameWithPlayers()
        XCTAssertTrue(app.staticTexts["Noite de Jogo"].waitForExistence(timeout: 6))

        app.buttons["Opções da partida"].tap()
        app.buttons["Apagar dados locais"].tap()
        let confirmDelete = app.buttons["confirm-delete-local-data"]
        XCTAssertTrue(confirmDelete.waitForExistence(timeout: 4))
        confirmDelete.tap()

        XCTAssertTrue(app.staticTexts["A mesa está pronta."].waitForExistence(timeout: 6))
    }

    func testPrimaryControlsExposeAccessibleLabels() throws {
        app.terminate()
        app = XCUIApplication()
        app.launchArguments = ["-ui-testing", "-screenshot-mode"]
        app.launch()

        let pixButton = app.buttons["home-action-PIX"]
        XCTAssertTrue(pixButton.waitForExistence(timeout: 8))
        XCTAssertTrue(pixButton.label.localizedCaseInsensitiveContains("PIX"))
        XCTAssertTrue(app.buttons["select-player-1"].label.contains("Ana, jogador ativo"))
        XCTAssertTrue(app.buttons["select-player-2"].label.contains("Bruno, selecionar como jogador ativo"))
        XCTAssertTrue(app.tabBars.buttons["Extrato"].label.contains("Extrato"))
    }

    func testPrivacyDisclosureExplainsLocalStorageAndVirtualCurrency() throws {
        XCTAssertTrue(app.staticTexts["A mesa está pronta."].waitForExistence(timeout: 8))
        app.buttons["privacy-info-button"].tap()

        XCTAssertTrue(app.navigationBars["Privacidade"].waitForExistence(timeout: 4))
        XCTAssertTrue(app.staticTexts["Seus dados ficam neste iPhone"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["privacy-virtual-currency"].exists)
    }

    private func createGameWithPlayers(first: String = "Ana", second: String = "Bruno") {
        app.buttons["create-game-button"].tap()
        XCTAssertTrue(app.buttons["continue-to-players"].waitForExistence(timeout: 5))
        app.buttons["continue-to-players"].tap()

        let firstName = app.textFields["player-name-1"]
        XCTAssertTrue(firstName.waitForExistence(timeout: 5))
        firstName.tap()
        firstName.typeText(first)
        let secondName = app.textFields["player-name-2"]
        secondName.tap()
        secondName.typeText(second)
        app.buttons["confirm-create-game"].tap()
    }

    private func openLeaderboard() {
        let openButton = app.buttons["show-leaderboard"]
        for _ in 0..<4 {
            if openButton.exists && openButton.isHittable { break }
            app.swipeDown()
        }
        for _ in 0..<5 {
            if openButton.exists && openButton.isHittable { break }
            app.swipeUp()
        }
        XCTAssertTrue(openButton.waitForExistence(timeout: 5))
        openButton.tap()
        XCTAssertTrue(app.navigationBars["Ranking"].waitForExistence(timeout: 5))
    }

    private func tapHomeAction(_ title: String) {
        let button = app.buttons["home-action-\(title)"]
        for _ in 0..<7 {
            if button.exists && button.isHittable { break }
            app.swipeUp()
        }
        XCTAssertTrue(button.waitForExistence(timeout: 5))
        XCTAssertTrue(button.isHittable)
        button.tap()
    }
}
