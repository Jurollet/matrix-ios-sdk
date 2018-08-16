/*
 Copyright 2018 New Vector Ltd

 Licensed under the Apache License, Version 2.0 (the "License");
 you may not use this file except in compliance with the License.
 You may obtain a copy of the License at

 http://www.apache.org/licenses/LICENSE-2.0

 Unless required by applicable law or agreed to in writing, software
 distributed under the License is distributed on an "AS IS" BASIS,
 WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 See the License for the specific language governing permissions and
 limitations under the License.
 */

#import <XCTest/XCTest.h>

#import "MatrixSDKTestsData.h"
#import "MXSDKOptions.h"

// Do not bother with retain cycles warnings in tests
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-retain-cycles"

@interface DirectRoomTests : XCTestCase
{
    MatrixSDKTestsData *matrixSDKTestsData;
}

@end

@implementation DirectRoomTests

- (void)setUp
{
    [super setUp];

    matrixSDKTestsData = [[MatrixSDKTestsData alloc] init];
}

- (void)tearDown
{
    [super tearDown];

    matrixSDKTestsData = nil;
}

// Create the following scenario with 3 rooms
// - Bob & Alice in a room
// - Bob sets the room as direct
// - Alice invites Bob in a direct chat
// - Charlie invites Bob in a direct chat
- (void)createScenario:(void (^)(MXSession *bobSession, NSString *aliceUserId, NSString *charlieUserId, XCTestExpectation *expectation))readyToTest
{
    // - Bob & Alice in a room
    [matrixSDKTestsData doMXSessionTestWithBobAndAliceInARoom:self readyToTest:^(MXSession *bobSession, MXRestClient *aliceRestClient, NSString *roomId, XCTestExpectation *expectation) {

        [matrixSDKTestsData doMXSessionTestWithAUser:nil readyToTest:^(MXSession *charlieSession, XCTestExpectation *expectation2) {

            __block id observer;
            observer = [[NSNotificationCenter defaultCenter] addObserverForName:kMXSessionDirectRoomsDidChangeNotification object:bobSession queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *note) {

                // Wait until we get the 3 direct rooms
                if (observer
                    && bobSession.directRooms[aliceRestClient.credentials.userId].count == 2
                    && bobSession.directRooms[charlieSession.myUser.userId].count == 1)
                {
                    [[NSNotificationCenter defaultCenter] removeObserver:observer];
                    observer = nil;

                    readyToTest(bobSession, aliceRestClient.credentials.userId, charlieSession.myUser.userId, expectation);
                }
            }];


            // - Bob set the room as direct
            MXRoom *room = [bobSession roomWithRoomId:roomId];
            [room setIsDirect:YES withUserId:aliceRestClient.credentials.userId success:nil failure:^(NSError *error) {
                XCTFail(@"The operation should not fail - NSError: %@", error);
                [expectation fulfill];
            }];

            // - Alice invites Bob in a direct chat
            [aliceRestClient createRoom:nil visibility:kMXRoomDirectoryVisibilityPrivate roomAlias:nil topic:nil invite:@[bobSession.myUser.userId] invite3PID:nil isDirect:YES preset:kMXRoomPresetPrivateChat success:nil failure:^(NSError *error) {
                XCTFail(@"The operation should not fail - NSError: %@", error);
                [expectation fulfill];
            }];

            // - Charlie invites Bob in a direct chat
            [charlieSession createRoom:nil visibility:kMXRoomDirectoryVisibilityPrivate roomAlias:nil topic:nil invite:@[bobSession.myUser.userId] invite3PID:nil isDirect:YES preset:kMXRoomPresetPrivateChat success:nil failure:^(NSError *error) {
                XCTFail(@"The operation should not fail - NSError: %@", error);
                [expectation fulfill];
            }];
        }];
    }];
}


// - Bob & Alice in a room
// - Bob must have no direct rooms at first
// - Bob set the room as direct
// -> On success the room must be tagged as direct
- (void)testMXRoom_setIsDirect
{
    // - Bob & Alice in a room
    [matrixSDKTestsData doMXSessionTestWithBobAndAliceInARoom:self readyToTest:^(MXSession *bobSession, MXRestClient *aliceRestClient, NSString *roomId, XCTestExpectation *expectation) {

        // - Bob must have no direct rooms at first
        XCTAssertEqual(bobSession.directRooms.count, 0);

        MXRoom *room = [bobSession roomWithRoomId:roomId];
        XCTAssertFalse(room.isDirect);

        // - Bob set the room as direct
        [room setIsDirect:YES withUserId:aliceRestClient.credentials.userId success:^{

            // -> On success the room must be tagged as direct
            XCTAssertTrue(room.isDirect);
            XCTAssertEqualObjects(room.directUserId, aliceRestClient.credentials.userId);

            XCTAssertEqual(bobSession.directRooms.count, 1);
            XCTAssertEqual(bobSession.directRooms[aliceRestClient.credentials.userId].count, 1);
            XCTAssertEqualObjects(bobSession.directRooms[aliceRestClient.credentials.userId].firstObject, roomId);

            [expectation fulfill];

        } failure:^(NSError *error) {
            XCTFail(@"The operation should not fail - NSError: %@", error);
            [expectation fulfill];
        }];

    }];
}

// - Bob & Alice in a room
// - Bob must have no direct rooms at first
// - Bob set the room as direct
// -> The kMXSessionDirectRoomsDidChangeNotification must be received with the
//    room marked as direct
// - Bob removes the room from direct rooms
// -> The kMXSessionDirectRoomsDidChangeNotification must be received with the
//    room no more marked as direct
- (void)testkMXSessionDirectRoomsDidChangeNotification_on_MXRoom_setIsDirect
{
    // - Bob & Alice in a room
    [matrixSDKTestsData doMXSessionTestWithBobAndAliceInARoom:self readyToTest:^(MXSession *bobSession, MXRestClient *aliceRestClient, NSString *roomId, XCTestExpectation *expectation) {

        // - Bob must have no direct rooms at first
        XCTAssertEqual(bobSession.directRooms.count, 0);

        MXRoom *room = [bobSession roomWithRoomId:roomId];
        XCTAssertFalse(room.isDirect);


        __block id observer;
        __block NSUInteger count = 0;
        observer = [[NSNotificationCenter defaultCenter] addObserverForName:kMXSessionDirectRoomsDidChangeNotification object:bobSession queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *note) {

            if (observer)
            {
                switch (count++)
                {
                    case 0:
                    {
                        // -> The kMXSessionDirectRoomsDidChangeNotification must be received with the
                        //    room marked as direct
                        XCTAssertTrue(room.isDirect);
                        XCTAssertEqualObjects(room.directUserId, aliceRestClient.credentials.userId);

                        XCTAssertEqual(bobSession.directRooms.count, 1);
                        XCTAssertEqual(bobSession.directRooms[aliceRestClient.credentials.userId].count, 1);
                        XCTAssertEqualObjects(bobSession.directRooms[aliceRestClient.credentials.userId].firstObject, roomId);

                        // - Bob removes the room from direct rooms
                        [room setIsDirect:NO withUserId:nil success:nil failure:^(NSError *error) {
                            XCTFail(@"The operation should not fail - NSError: %@", error);
                            [expectation fulfill];
                        }];

                        break;
                    }

                    case 1:

                        // -> The kMXSessionDirectRoomsDidChangeNotification must be received with the
                        //    room no more marked as direct
                        XCTAssertFalse(room.isDirect);
                        XCTAssertNil(room.directUserId);

                        XCTAssertEqual(bobSession.directRooms.count, 0);

                        [[NSNotificationCenter defaultCenter] removeObserver:observer];
                        observer = nil;
                        [expectation fulfill];

                        break;

                    default:
                        break;
                }
            }
        }];


        // - Bob set the room as direct
        [room setIsDirect:YES withUserId:aliceRestClient.credentials.userId success:nil failure:^(NSError *error) {
            XCTFail(@"The operation should not fail - NSError: %@", error);
            [expectation fulfill];
        }];
    }];
}

// - Alice invites Bob in a direct chat
// -> Bob must see it as a direct room
- (void)testDirectRoomInvite
{
    [matrixSDKTestsData doMXSessionTestWithBobAndAliceInARoom:self readyToTest:^(MXSession *bobSession, MXRestClient *aliceRestClient, NSString *aRoomId, XCTestExpectation *expectation) {

        // Should be kMXSessionNewRoomNotification
        __block id observer;
        observer = [[NSNotificationCenter defaultCenter] addObserverForName:kMXSessionDirectRoomsDidChangeNotification object:bobSession queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *note) {

            if (observer)
            {
                [[NSNotificationCenter defaultCenter] removeObserver:observer];
                observer = nil;
                
                // -> Bob must see it as a direct room
                XCTAssertEqual(bobSession.directRooms.count, 1);
                XCTAssertEqual(bobSession.directRooms[aliceRestClient.credentials.userId].count, 1);

                NSString *roomId = bobSession.directRooms[aliceRestClient.credentials.userId].firstObject;
                MXRoom *room = [bobSession roomWithRoomId:roomId];

                XCTAssertTrue(room.isDirect);
                XCTAssertEqualObjects(room.directUserId, aliceRestClient.credentials.userId);

                [expectation fulfill];
            }
        }];


        // - Alice invites Bob in a direct chat
        [aliceRestClient createRoom:nil visibility:kMXRoomDirectoryVisibilityPrivate roomAlias:nil topic:nil invite:@[bobSession.myUser.userId] invite3PID:nil isDirect:YES preset:kMXRoomPresetPrivateChat success:nil failure:^(NSError *error) {

            XCTFail(@"The operation should not fail - NSError: %@", error);
            [expectation fulfill];
        }];
    }];
}

// After the scenario:
// - Bob does an initial /sync
// -> He must still see 2 direct rooms with Alice and 1 with Charlie
- (void)testDirectRoomsAfterInitialSync
{
    [self createScenario:^(MXSession *bobSession, NSString *aliceUserId, NSString *charlieUserId, XCTestExpectation *expectation) {

        // - Bob does an initial /sync
        MXSession *bobSession2 = [[MXSession alloc] initWithMatrixRestClient:bobSession.matrixRestClient];
        [matrixSDKTestsData retain:bobSession2];
        [bobSession close];

        [bobSession2 start:^{

            // -> He must still see 2 direct rooms with Alice and 1 with Charlie
            XCTAssertEqual(bobSession2.directRooms[aliceUserId].count, 2);
            XCTAssertEqual(bobSession2.directRooms[charlieUserId].count, 1);
            [expectation fulfill];

        } failure:^(NSError *error) {
            XCTFail(@"The operation should not fail - NSError: %@", error);
            [expectation fulfill];
        }];
    }];
}

// After the scenario:
// - Bob makes the room with Charlie no more direct
// - Bob makes one room with Alice no more direct
// - Bob makes the room with Charlie direct again
// -> Bob must have one direct room with Alice and one direct room with Charlie at the end
// In case of race condtions in the code, this test can randomly fails.
- (void)testDirectRoomsRaceConditions
{
    [self createScenario:^(MXSession *bobSession, NSString *aliceUserId, NSString *charlieUserId, XCTestExpectation *expectation) {

        MXRoom *roomWithCharlie = [bobSession roomWithRoomId:bobSession.directRooms[charlieUserId].firstObject];
        MXRoom *roomWithAlice = [bobSession roomWithRoomId:bobSession.directRooms[aliceUserId].firstObject];

        __block id observer;
        observer = [[NSNotificationCenter defaultCenter] addObserverForName:kMXSessionDirectRoomsDidChangeNotification object:bobSession queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *note) {

            NSLog(@"[testDirectRoomsRaceConditions] Direct rooms with Alice: %@", @(bobSession.directRooms[aliceUserId].count));
            NSLog(@"[testDirectRoomsRaceConditions] Direct rooms with Charlie: %@", @(bobSession.directRooms[charlieUserId].count));

            // Wait until we get the 2 expected direct rooms
            if (observer
                && bobSession.directRooms[aliceUserId].count == 1
                && bobSession.directRooms[charlieUserId].count == 1)
            {
                [[NSNotificationCenter defaultCenter] removeObserver:observer];
                observer = nil;

                [expectation fulfill];
            }
        }];

        [roomWithCharlie setIsDirect:NO withUserId:nil success:nil failure:^(NSError *error) {
            XCTFail(@"The operation should not fail - NSError: %@", error);
            [expectation fulfill];
        }];

        [roomWithAlice setIsDirect:NO withUserId:nil success:nil failure:^(NSError *error) {
            XCTFail(@"The operation should not fail - NSError: %@", error);
            [expectation fulfill];
        }];

        [roomWithCharlie setIsDirect:YES withUserId:nil success:nil failure:^(NSError *error) {
            XCTFail(@"The operation should not fail - NSError: %@", error);
            [expectation fulfill];
        }];


    }];
}

@end

#pragma clang diagnostic pop
