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
        app.buttons["create-game-button"].tap()
        XCTAssertTrue(app.navigationBars["Nova partida"].waitForExistence(timeout: 4))
        app.buttons["confirm-create-game"].tap()

        XCTAssertTrue(app.staticTexts["Noite de Jogo"].waitForExistence(timeout: 6))
        XCTAssertTrue(app.staticTexts["M$ 2.450,00"].waitForExistence(timeout: 4))
        app.buttons["PIX interno"].tap()
        XCTAssertTrue(app.navigationBars["PIX Imobiliário"].waitForExistence(timeout: 4))
        let amountField = app.textFields["transfer-amount-field"]
        XCTAssertTrue(amountField.waitForExistence(timeout: 3))
        amountField.tap()
        amountField.typeText("50")
        app.buttons["Confirmar"].tap()

        XCTAssertTrue(app.staticTexts["M$ 2.400,00"].waitForExistence(timeout: 5))
        app.tabBars.buttons["Extrato"].tap()
        XCTAssertTrue(app.staticTexts["PIX Imobiliário"].waitForExistence(timeout: 5))
    }

    func testPremiumBoardTabIsReachable() throws {
        app.terminate()
        app = XCUIApplication()
        app.launchArguments = ["-ui-testing", "-screenshot-mode", "-capture-tab-board"]
        app.launch()
        XCTAssertTrue(app.buttons["roll-board-dice"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["Sua jogada"].exists)
    }

    func testPropertyPurchaseIsVisibleInStatement() throws {
        app.terminate()
        app = XCUIApplication()
        app.launchArguments = ["-ui-testing", "-screenshot-mode", "-capture-tab-properties"]
        app.launch()
        XCTAssertTrue(app.staticTexts["Rua do Ipê"].waitForExistence(timeout: 8))
        app.buttons["buy-property-1"].tap()
        app.tabBars.buttons["Extrato"].tap()
        XCTAssertTrue(app.staticTexts["Compra: Rua do Ipê"].waitForExistence(timeout: 6))
    }

    func testChargeWaitsForPayerThenRecordsPayment() throws {
        app.buttons["create-game-button"].tap()
        app.buttons["confirm-create-game"].tap()
        XCTAssertTrue(app.staticTexts["Noite de Jogo"].waitForExistence(timeout: 6))
        app.buttons["home-action-Cobrar"].tap()
        XCTAssertTrue(app.navigationBars["Nova cobrança"].waitForExistence(timeout: 4))
        let amountField = app.textFields["charge-amount-field"]
        XCTAssertTrue(amountField.waitForExistence(timeout: 3))
        amountField.tap()
        amountField.typeText("40")
        app.buttons["create-charge-button"].tap()

        XCTAssertTrue(app.staticTexts["Cobranças aguardando"].waitForExistence(timeout: 5))
        app.buttons["Pagar"].tap()
        XCTAssertTrue(app.staticTexts["M$ 2.490,00"].waitForExistence(timeout: 5))
    }
}
