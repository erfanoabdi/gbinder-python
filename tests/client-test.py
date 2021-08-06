import ITest

service = ITest.get_service()
if service:
    while True:
        value = input("Say something: ")
        ret = service.sendTest(value)
        print(ret)
