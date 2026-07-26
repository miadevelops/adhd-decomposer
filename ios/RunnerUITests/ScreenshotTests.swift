import XCTest

class ScreenshotTests: XCTestCase {
    
    let app = XCUIApplication()
    
    override func setUpWithError() throws {
        continueAfterFailure = false
        app.launchArguments = ["--screenshot-mode"]
        setupSnapshot(app)
        app.launch()
    }
    
    func testScreenshots() throws {
        // 1. Welcome/Onboarding screen
        snapshot("01_Welcome")
        
        // Tap "Get Started" or skip onboarding if already done
        if app.buttons["Get Started"].exists {
            app.buttons["Get Started"].tap()
            sleep(1)
            snapshot("02_Challenge_Select")
            
            // Select a challenge
            app.staticTexts["Starting tasks"].tap()
            app.buttons["Continue"].tap()
            sleep(1)
        }
        
        // 2. Home screen (empty state or with tasks)
        snapshot("03_Home")
        
        // 3. New task / Decompose screen
        if app.buttons["New Task"].exists {
            app.buttons["New Task"].tap()
            sleep(1)
            snapshot("04_New_Task")
            
            // Type a sample task
            let textField = app.textFields.firstMatch
            if textField.exists {
                textField.tap()
                textField.typeText("Clean my room")
                app.buttons["Break it down"].tap()
                sleep(3) // Wait for AI response
                snapshot("05_Task_Breakdown")
            }
            
            // Start the task
            if app.buttons["Start"].exists {
                app.buttons["Start"].tap()
                sleep(1)
                snapshot("06_Execute_Task")
            }
        }
        
        // 4. Templates screen
        app.navigationBars.buttons.element(boundBy: 0).tap() // Back
        sleep(1)
        if app.buttons["Templates"].exists {
            app.buttons["Templates"].tap()
            sleep(1)
            snapshot("07_Templates")
            app.navigationBars.buttons.element(boundBy: 0).tap()
        }
        
        // 5. Progress screen
        let progressBadge = app.buttons.matching(
            NSPredicate(format: "label BEGINSWITH 'Level ' AND label CONTAINS 'Tap to view progress'")
        ).firstMatch
        if progressBadge.exists {
            progressBadge.tap()
            sleep(1)
            snapshot("08_Stats")
            app.navigationBars.buttons.element(boundBy: 0).tap()
        }
        
        // 6. Settings
        if app.buttons["Settings"].exists || app.images["settings_outlined"].exists {
            app.buttons["Settings"].firstMatch.tap()
            sleep(1)
            snapshot("09_Settings")
        }
    }
}
