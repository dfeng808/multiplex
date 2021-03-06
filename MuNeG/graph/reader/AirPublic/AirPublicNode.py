__author__ = 'Adrian'


class AirPublicNode:

    id = 0
    name = ''
    longitude = 0.0
    latitude = 0.0
    label = 0

    def __init__(self, id, name='', longitude=0.0, latitude=0.0, label = 0):
        self.id = id
        self.name = name
        self.longitude = longitude
        self.latitude = latitude
        self.label = label

    def __repr__(self):
        return str(self.name)
