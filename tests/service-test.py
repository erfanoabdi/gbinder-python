import ITest

def sendTest(value):
    print(value)
    return value

ITest.add_service(sendTest)
